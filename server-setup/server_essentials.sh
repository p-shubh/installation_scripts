#!/bin/bash
# =============================================================================
#  essentials.sh - Ubuntu Server Essentials
#  Purpose: Firewall + VPN + Gemma4 AI inference server
#  Run as root after harden.sh has already been applied.
#
#  What it does:
#    1. System update + essential packages
#    2. Timezone and locale
#    3. Swap file (for Gemma4 model memory headroom)
#    4. System monitoring tools
#    5. Kernel / sysctl tuning (network + GPU memory)
#    6. GPU driver readiness check
#    7. Docker + NVIDIA container toolkit (for Gemma4)
#    8. Automatic security updates
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}=== $* ===${NC}"; }

[[ $EUID -ne 0 ]] && error "Run this script as root."

# -- CONFIG -------------------------------------------------------------------
TIMEZONE="UTC"                  # Change e.g. Asia/Kolkata
SWAP_SIZE="8G"                  # 8G recommended for Gemma4 4B model overflow
LOCALE="en_US.UTF-8"
# -----------------------------------------------------------------------------

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}   Ubuntu Essentials Setup${NC}"
echo -e "${BOLD}   Firewall + VPN + Gemma4 Server${NC}"
echo -e "${BOLD}============================================${NC}"
echo ""

# =============================================================================
#  STEP 1 - System update + essential packages
# =============================================================================
section "System Update + Essential Packages"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl wget git vim nano unzip tar \
    build-essential ca-certificates gnupg lsb-release \
    software-properties-common apt-transport-https \
    htop iotop iftop nethogs nload \
    net-tools iproute2 iputils-ping dnsutils \
    tcpdump nmap ss \
    sysstat atop \
    jq tree ncdu \
    fail2ban ufw \
    cron logrotate \
    linux-headers-$(uname -r)

info "Essential packages installed."

# =============================================================================
#  STEP 2 - Timezone and locale
# =============================================================================
section "Timezone and Locale"

timedatectl set-timezone "$TIMEZONE"
info "Timezone set to: $(timedatectl | grep 'Time zone' | awk '{print $3}')"

locale-gen "$LOCALE" > /dev/null 2>&1
update-locale LANG="$LOCALE" LC_ALL="$LOCALE" > /dev/null 2>&1
info "Locale set to: $LOCALE"

# Sync hardware clock
timedatectl set-ntp true
info "NTP sync enabled."

# =============================================================================
#  STEP 3 - Swap file
# =============================================================================
section "Swap File Setup (${SWAP_SIZE})"

SWAPFILE="/swapfile"

if swapon --show | grep -q "$SWAPFILE"; then
    info "Swap already active at ${SWAPFILE} - skipping."
else
    if [[ -f "$SWAPFILE" ]]; then
        warn "Swapfile exists but not active - re-enabling."
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE" > /dev/null
        swapon "$SWAPFILE"
    else
        fallocate -l "$SWAP_SIZE" "$SWAPFILE"
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE" > /dev/null
        swapon "$SWAPFILE"
        info "Swap created: ${SWAP_SIZE} at ${SWAPFILE}"
    fi

    # Persist across reboots
    if ! grep -q "$SWAPFILE" /etc/fstab; then
        echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
        info "Swap added to /etc/fstab (persists on reboot)."
    fi
fi

# Tune swappiness - low value = only use swap when RAM is nearly full
# For AI inference we want RAM priority, swap only as emergency overflow
sysctl -w vm.swappiness=10 > /dev/null
sysctl -w vm.vfs_cache_pressure=50 > /dev/null
grep -q "vm.swappiness" /etc/sysctl.conf && \
    sed -i 's/^vm.swappiness.*/vm.swappiness=10/' /etc/sysctl.conf || \
    echo "vm.swappiness=10" >> /etc/sysctl.conf
grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf && \
    sed -i 's/^vm.vfs_cache_pressure.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf || \
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

info "Swappiness set to 10 (RAM-priority, swap as overflow only)."
free -h | grep -E "Mem|Swap"

# =============================================================================
#  STEP 4 - Kernel / sysctl tuning
# =============================================================================
section "Kernel and Network Tuning"

cat >> /etc/sysctl.conf <<EOF

# --- essentials.sh tuning ---
# Network performance
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.core.netdev_max_backlog=5000
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# Security hardening
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv6.conf.all.accept_redirects=0
net.ipv4.tcp_syncookies=1

# File descriptor limits (needed for VPN + inference server)
fs.file-max=2097152
EOF

sysctl -p > /dev/null 2>&1
info "Kernel parameters applied (BBR congestion control, network tuning, security)."

# Increase open file limits for services
cat > /etc/security/limits.d/99-essentials.conf <<EOF
* soft nofile 65536
* hard nofile 131072
root soft nofile 65536
root hard nofile 131072
EOF
info "File descriptor limits increased."

# =============================================================================
#  STEP 5 - System monitoring tools config
# =============================================================================
section "System Monitoring Setup"

# Enable sysstat for historical stats (sar, iostat)
if [[ -f /etc/default/sysstat ]]; then
    sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
    systemctl enable --now sysstat > /dev/null 2>&1 || true
    info "sysstat enabled (use 'sar' for historical CPU/IO/memory stats)."
fi

# Useful monitoring aliases for root
cat > /root/.bash_aliases <<EOF
# System monitoring shortcuts
alias ports='ss -tulpn'
alias connections='ss -tnp'
alias mem='free -h'
alias disk='df -h'
alias topcpu='ps aux --sort=-%cpu | head -15'
alias topmem='ps aux --sort=-%mem | head -15'
alias netwatch='iftop -i \$(ip route | grep default | awk "{print \$5}" | head -1)'
alias gpuwatch='watch -n1 nvidia-smi'
alias swapon='swapon --show'
alias kernlog='journalctl -k -f'
alias sshlog='journalctl -u sshd -f'
alias f2bstatus='fail2ban-client status sshd'
EOF

# Make aliases available immediately
[[ -f /root/.bashrc ]] && grep -q ".bash_aliases" /root/.bashrc || \
    echo '[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases' >> /root/.bashrc

info "Monitoring aliases added to /root/.bash_aliases"
info "  ports, connections, mem, disk, topcpu, topmem, netwatch, gpuwatch, f2bstatus"

# =============================================================================
#  STEP 6 - GPU driver readiness
# =============================================================================
section "GPU Driver Check (for Gemma4 inference)"

if command -v nvidia-smi &>/dev/null; then
    info "NVIDIA driver already installed:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    warn "NVIDIA driver not found. Installing CUDA keyring for driver install..."
    # Add NVIDIA CUDA repo keyring
    CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb"
    TMP_DEB=$(mktemp /tmp/cuda-keyring-XXXX.deb)
    if wget -q "$CUDA_KEYRING_URL" -O "$TMP_DEB"; then
        dpkg -i "$TMP_DEB" > /dev/null 2>&1
        rm -f "$TMP_DEB"
        apt-get update -qq
        info "CUDA repo added. To install drivers run:"
        info "  apt-get install -y nvidia-driver-550 nvidia-cuda-toolkit"
        info "  reboot"
    else
        warn "Could not reach NVIDIA repo. Install drivers manually after setup."
    fi
fi

# =============================================================================
#  STEP 7 - Docker + NVIDIA container toolkit
# =============================================================================
section "Docker + NVIDIA Container Toolkit"

if command -v docker &>/dev/null; then
    info "Docker already installed: $(docker --version)"
else
    info "Installing Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    info "Docker installed and started."
fi

# NVIDIA container toolkit (for GPU-accelerated Docker containers)
if ! dpkg -l | grep -q nvidia-container-toolkit 2>/dev/null; then
    info "Installing NVIDIA container toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker > /dev/null 2>&1 || true
    systemctl restart docker 2>/dev/null || true
    info "NVIDIA container toolkit installed (GPU passthrough to Docker enabled)."
else
    info "NVIDIA container toolkit already installed."
fi

# =============================================================================
#  STEP 8 - Automatic security updates
# =============================================================================
section "Automatic Security Updates"

apt-get install -y -qq unattended-upgrades update-notifier-common

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl enable --now unattended-upgrades > /dev/null 2>&1
info "Automatic security updates enabled (no auto-reboot)."

# =============================================================================
#  DONE
# =============================================================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Essentials setup complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Timezone        : $(timedatectl | grep 'Time zone' | awk '{print $3}')"
echo "  Locale          : $LOCALE"
echo "  Swap            : $(free -h | grep Swap | awk '{print $2}')"
echo "  Swappiness      : $(cat /proc/sys/vm/swappiness)"
echo "  Docker          : $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
echo "  Auto updates    : enabled"
echo "  BBR             : $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
echo ""
warn "If GPU drivers were just installed, reboot before running Gemma4."
warn "Source aliases now with: source /root/.bash_aliases"