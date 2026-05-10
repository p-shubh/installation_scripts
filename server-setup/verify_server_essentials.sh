#!/bin/bash
# =============================================================================
#  verify_essentials.sh - Verifies essentials.sh ran correctly
#  Run as root.
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0

ok()      { echo -e "  ${GREEN}[PASS]${NC} $*"; ((PASS++)); }
fail()    { echo -e "  ${RED}[FAIL]${NC} $*"; ((FAIL++)); }
warn()    { echo -e "  ${YELLOW}[WARN]${NC} $*"; ((WARN++)); }
section() { echo -e "\n${CYAN}${BOLD}--- $* ---${NC}"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}Run as root.${NC}"; exit 1; }

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}   essentials.sh Verification Report${NC}"
echo -e "${BOLD}============================================${NC}"

# =============================================================================
#  1 - Core packages
# =============================================================================
section "Essential Packages"

PACKAGES=(curl wget git vim htop iotop iftop nethogs net-tools \
          nload sysstat atop jq tree ncdu ufw fail2ban \
          unattended-upgrades docker-ce nvidia-container-toolkit)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        ok "$pkg installed"
    else
        warn "$pkg not installed"
    fi
done

# =============================================================================
#  2 - Timezone and locale
# =============================================================================
section "Timezone and Locale"

TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [[ -n "$TZ" ]]; then
    ok "Timezone set: $TZ"
else
    fail "Timezone not configured"
fi

NTP=$(timedatectl | grep "NTP service" | awk '{print $3}')
[[ "$NTP" == "active" ]] && ok "NTP sync: active" || warn "NTP sync not active"

LANG_SET=$(locale | grep "^LANG=" | cut -d= -f2)
[[ -n "$LANG_SET" ]] && ok "Locale set: $LANG_SET" || warn "Locale not set"

# =============================================================================
#  3 - Swap
# =============================================================================
section "Swap File"

if swapon --show | grep -q "/swapfile"; then
    SWAP_SIZE=$(swapon --show | grep /swapfile | awk '{print $3}')
    ok "Swap active: $SWAP_SIZE"
else
    fail "Swap not active"
fi

if grep -q "/swapfile" /etc/fstab; then
    ok "Swap persists in /etc/fstab"
else
    fail "Swap not in /etc/fstab (will not survive reboot)"
fi

SWAPPINESS=$(cat /proc/sys/vm/swappiness)
[[ "$SWAPPINESS" -le 10 ]] && ok "Swappiness: $SWAPPINESS (RAM-priority)" || warn "Swappiness: $SWAPPINESS (recommended <= 10 for inference)"

# =============================================================================
#  4 - Kernel tuning
# =============================================================================
section "Kernel and Network Tuning"

BBR=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
[[ "$BBR" == "bbr" ]] && ok "TCP congestion control: BBR" || warn "BBR not active (got: $BBR)"

RP=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)
[[ "$RP" == "1" ]] && ok "Reverse path filtering: enabled" || warn "Reverse path filtering not set"

SYNCOOKIES=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)
[[ "$SYNCOOKIES" == "1" ]] && ok "TCP SYN cookies: enabled" || warn "TCP SYN cookies not enabled"

REDIRECTS=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null)
[[ "$REDIRECTS" == "0" ]] && ok "ICMP redirects: disabled" || warn "ICMP redirects not disabled"

FILEMAX=$(sysctl -n fs.file-max 2>/dev/null)
[[ "$FILEMAX" -ge 1000000 ]] && ok "Max open files: $FILEMAX" || warn "Max open files: $FILEMAX (recommended >= 1000000)"

if [[ -f /etc/security/limits.d/99-essentials.conf ]]; then
    ok "File descriptor limits config exists"
else
    warn "File descriptor limits config not found"
fi

# =============================================================================
#  5 - Monitoring tools
# =============================================================================
section "System Monitoring"

for tool in htop iotop iftop nethogs sar atop; do
    command -v "$tool" &>/dev/null && ok "$tool available" || warn "$tool not found"
done

[[ -f /root/.bash_aliases ]] && ok "Monitoring aliases installed (/root/.bash_aliases)" || warn "Monitoring aliases not found"

SYSSTAT=$(systemctl is-active sysstat 2>/dev/null || echo "inactive")
[[ "$SYSSTAT" == "active" ]] && ok "sysstat service: active" || warn "sysstat service: $SYSSTAT"

# =============================================================================
#  6 - GPU
# =============================================================================
section "GPU / NVIDIA"

if command -v nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -n1)
    GPU_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
    ok "NVIDIA driver: $GPU_DRIVER"
    ok "GPU: $GPU_NAME ($GPU_MEM VRAM)"

    # Check VRAM for Gemma4
    MEM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ' ')
    if [[ "$MEM_MB" -ge 8000 ]]; then
        ok "VRAM sufficient for Gemma4 2B (>= 8GB)"
    else
        warn "VRAM may be low for Gemma4 2B (got ${MEM_MB}MB, recommend >= 8GB)"
    fi
    if [[ "$MEM_MB" -ge 16000 ]]; then
        ok "VRAM sufficient for Gemma4 4B (>= 16GB)"
    else
        warn "VRAM insufficient for Gemma4 4B (got ${MEM_MB}MB, recommend >= 16GB)"
    fi
else
    warn "nvidia-smi not found - GPU drivers not installed or reboot needed"
fi

if dpkg -l nvidia-container-toolkit 2>/dev/null | grep -q "^ii"; then
    ok "NVIDIA container toolkit installed"
else
    warn "NVIDIA container toolkit not installed"
fi

# =============================================================================
#  7 - Docker
# =============================================================================
section "Docker"

if command -v docker &>/dev/null; then
    ok "Docker installed: $(docker --version | cut -d' ' -f3 | tr -d ',')"
else
    fail "Docker not installed"
fi

DOCKER_STATUS=$(systemctl is-active docker 2>/dev/null || echo "inactive")
[[ "$DOCKER_STATUS" == "active" ]] && ok "Docker service: active" || fail "Docker service: $DOCKER_STATUS"

DOCKER_ENABLED=$(systemctl is-enabled docker 2>/dev/null || echo "disabled")
[[ "$DOCKER_ENABLED" == "enabled" ]] && ok "Docker enabled on boot" || warn "Docker not enabled on boot"

# GPU in Docker
if command -v docker &>/dev/null && command -v nvidia-smi &>/dev/null; then
    if docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi &>/dev/null; then
        ok "GPU passthrough to Docker: working"
    else
        warn "GPU passthrough to Docker: not verified (may need reboot or driver install)"
    fi
fi

# =============================================================================
#  8 - Automatic security updates
# =============================================================================
section "Automatic Security Updates"

if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
    ok "auto-upgrades config exists"
else
    fail "auto-upgrades config not found"
fi

if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
    ok "unattended-upgrades config exists"
else
    fail "unattended-upgrades config not found"
fi

UU_STATUS=$(systemctl is-active unattended-upgrades 2>/dev/null || echo "inactive")
[[ "$UU_STATUS" == "active" ]] && ok "unattended-upgrades service: active" || warn "unattended-upgrades service: $UU_STATUS"

# =============================================================================
#  SUMMARY
# =============================================================================
TOTAL_CHECKS=$((PASS + FAIL + WARN))
echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}   Summary${NC}"
echo -e "${BOLD}============================================${NC}"
echo -e "  Total checks : ${TOTAL_CHECKS}"
echo -e "  ${GREEN}Passed       : ${PASS}${NC}"
echo -e "  ${RED}Failed       : ${FAIL}${NC}"
echo -e "  ${YELLOW}Warnings     : ${WARN}${NC}"
echo ""

if [[ $FAIL -eq 0 && $WARN -eq 0 ]]; then
    echo -e "${GREEN}  All checks passed. essentials.sh ran successfully.${NC}"
elif [[ $FAIL -eq 0 ]]; then
    echo -e "${YELLOW}  No failures. ${WARN} warning(s) - review above (some may need a reboot).${NC}"
else
    echo -e "${RED}  ${FAIL} failure(s) found. essentials.sh may not have completed correctly.${NC}"
fi
echo ""