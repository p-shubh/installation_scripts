#!/bin/bash
# =============================================================================
#  secure_server_26.sh — Post-creation server hardening for Ubuntu 26+
#  Run as root immediately after server creation.
#
#  Key difference from secure_server.sh:
#    On Ubuntu 24+/26+, /etc/ssh/sshd_config.d/50-cloud-init.conf sets
#    PasswordAuthentication yes. OpenSSH processes included drop-ins before
#    the main sshd_config and first-match wins, so editing sshd_config
#    directly is silently overridden. This script:
#      1. Neutralises the conflicting line in 50-cloud-init.conf
#      2. Writes all hardened settings to 99-harden.conf (drop-in)
#
#  Updated: Added STEP 5 — CVE-2026-31431 (Copy Fail) mitigation
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run this script as root."

# ── CONFIG — edit these before running ───────────────────────────────────────
SSH_PORT=22
ALLOWED_PORTS=(80 443)
# Paste your public key here if not already in /root/.ssh/authorized_keys.
# Leave empty to skip (key must already be present).
ROOT_PUBLIC_KEY="${ROOT_PUBLIC_KEY:-""}"

# =============================================================================
#  STEP 1 — SSH key setup
# =============================================================================
info "Configuring /root/.ssh/authorized_keys …"
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

if [[ -n "$ROOT_PUBLIC_KEY" ]]; then
    if ! grep -qF "$ROOT_PUBLIC_KEY" /root/.ssh/authorized_keys 2>/dev/null; then
        echo "$ROOT_PUBLIC_KEY" >> /root/.ssh/authorized_keys
        info "Public key added to authorized_keys."
    else
        info "Public key already present — skipping."
    fi
else
    warn "ROOT_PUBLIC_KEY is empty. Make sure a key is already in /root/.ssh/authorized_keys before you proceed, or you will be locked out."
fi

if [[ ! -s /root/.ssh/authorized_keys ]]; then
    error "No SSH keys found in /root/.ssh/authorized_keys. Add a key first to avoid being locked out."
fi

# =============================================================================
#  STEP 2 — Harden SSH daemon via drop-in
# =============================================================================
info "Hardening SSH configuration …"

SSHD_CONFIG="/etc/ssh/sshd_config"
DROPIN_DIR="/etc/ssh/sshd_config.d"
DROPIN_FILE="${DROPIN_DIR}/99-harden.conf"
CLOUD_INIT_CONF="${DROPIN_DIR}/50-cloud-init.conf"

cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"

# 50-cloud-init.conf sets PasswordAuthentication yes which silently beats
# anything in the main sshd_config (drop-ins are included first, first-match
# wins). Comment it out so 99-harden.conf becomes the sole authority.
if [[ -f "$CLOUD_INIT_CONF" ]]; then
    cp "$CLOUD_INIT_CONF" "${CLOUD_INIT_CONF}.bak.$(date +%s)"
    sed -i 's/^\(PasswordAuthentication\b\)/#\1/' "$CLOUD_INIT_CONF"
    info "Neutralized conflicting PasswordAuthentication in 50-cloud-init.conf."
fi

mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_FILE" <<EOF
# Managed by secure_server_26.sh — do not edit manually
Port                             ${SSH_PORT}
PermitRootLogin                  prohibit-password
PasswordAuthentication           no
PubkeyAuthentication             yes
AuthenticationMethods            publickey
ChallengeResponseAuthentication  no
KbdInteractiveAuthentication     no
UsePAM                           yes
PermitEmptyPasswords             no
X11Forwarding                    no
AllowAgentForwarding             no
AllowTcpForwarding               no
MaxAuthTries                     3
LoginGraceTime                   30
ClientAliveInterval              300
ClientAliveCountMax              2
EOF

sshd -t || error "sshd_config validation failed. Check ${DROPIN_FILE}."
systemctl restart sshd
info "SSH hardened and restarted (port ${SSH_PORT}, root key-only)."

# =============================================================================
#  STEP 3 — Fail2ban
# =============================================================================
info "Installing Fail2ban …"
apt-get update -qq
apt-get install -y -qq fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = ${SSH_PORT}
filter   = sshd
maxretry = 3
bantime  = 24h
EOF

systemctl enable --now fail2ban
systemctl restart fail2ban
info "Fail2ban active (SSH jail: 3 retries → 24 h ban)."

# =============================================================================
#  STEP 4 — UFW Firewall
# =============================================================================
info "Configuring UFW firewall …"
apt-get install -y -qq ufw

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp" comment "SSH"

for port in "${ALLOWED_PORTS[@]}"; do
    ufw allow "${port}/tcp" comment "Custom allow"
    info "  Opened port ${port}/tcp"
done

ufw --force enable
ufw status verbose
info "UFW enabled."

# =============================================================================
#  STEP 5 — Mitigate CVE-2026-31431 (Copy Fail / algif_aead)
# =============================================================================
info "Mitigating CVE-2026-31431 — disabling algif_aead kernel module …"
modprobe -r algif_aead 2>/dev/null || true
echo "blacklist algif_aead" | tee /etc/modprobe.d/disable-algif-aead.conf
info "algif_aead disabled and blacklisted."

# =============================================================================
#  DONE
# =============================================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Server hardening complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  SSH port          : ${SSH_PORT}"
echo "  Root login        : key only (PermitRootLogin prohibit-password)"
echo "  Password auth     : DISABLED"
echo "  Drop-in config    : ${DROPIN_FILE}"
echo "  Fail2ban          : active  (fail2ban-client status sshd)"
echo "  Firewall          : active  (ufw status)"
echo "  CVE-2026-31431    : mitigated (algif_aead blacklisted)"
echo ""
warn "Open a NEW terminal and verify SSH key login works BEFORE closing this session."