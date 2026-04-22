#!/bin/bash
# =============================================================================
#  harden.sh — Post-creation server hardening script
#  Run as root immediately after server creation.
#  What it does:
#    1. Enables root login via SSH key only (no password, no other auth)
#    2. Installs and configures Fail2ban
#    3. Sets up UFW firewall rules
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run this script as root."

# ── CONFIG — edit these before running ───────────────────────────────────────
SSH_PORT=22                          # Change if you want a non-standard port
ALLOWED_PORTS=(80 443)               # Extra TCP ports to open (web, etc.)
# Paste your public key here if you haven't already added it to authorized_keys
# Leave empty to skip (key must already be in /root/.ssh/authorized_keys)
ROOT_PUBLIC_KEY=""

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

# Guard: refuse to continue if no keys are present
if [[ ! -s /root/.ssh/authorized_keys ]]; then
    error "No SSH keys found in /root/.ssh/authorized_keys. Add a key first to avoid being locked out."
fi

# =============================================================================
#  STEP 2 — Harden SSH daemon
# =============================================================================
info "Hardening SSH configuration …"

SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%s)"

apply_sshd_setting() {
    local key="$1" val="$2"
    if grep -qE "^#?\s*${key}\s" "$SSHD_CONFIG"; then
        sed -i "s|^#\?\s*${key}\s.*|${key} ${val}|" "$SSHD_CONFIG"
    else
        echo "${key} ${val}" >> "$SSHD_CONFIG"
    fi
}

apply_sshd_setting "Port"                    "$SSH_PORT"
apply_sshd_setting "PermitRootLogin"         "prohibit-password"   # root allowed, key only
apply_sshd_setting "PasswordAuthentication"  "no"
apply_sshd_setting "PubkeyAuthentication"    "yes"
apply_sshd_setting "AuthenticationMethods"   "publickey"
apply_sshd_setting "ChallengeResponseAuthentication" "no"
apply_sshd_setting "KbdInteractiveAuthentication"    "no"
apply_sshd_setting "UsePAM"                  "yes"
apply_sshd_setting "PermitEmptyPasswords"    "no"
apply_sshd_setting "X11Forwarding"           "no"
apply_sshd_setting "AllowAgentForwarding"    "no"
apply_sshd_setting "AllowTcpForwarding"      "no"
apply_sshd_setting "MaxAuthTries"            "3"
apply_sshd_setting "LoginGraceTime"          "30"
apply_sshd_setting "ClientAliveInterval"     "300"
apply_sshd_setting "ClientAliveCountMax"     "2"

# Validate config before reloading
sshd -t || error "sshd_config validation failed. Check ${SSHD_CONFIG}."
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

# Reset to defaults (non-interactive)
ufw --force reset

ufw default deny incoming
ufw default allow outgoing

# SSH
ufw allow "${SSH_PORT}/tcp" comment "SSH"

# Any additional ports
for port in "${ALLOWED_PORTS[@]}"; do
    ufw allow "${port}/tcp" comment "Custom allow"
    info "  Opened port ${port}/tcp"
done

ufw --force enable
ufw status verbose
info "UFW enabled."

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
echo "  Fail2ban          : active  (fail2ban-client status sshd)"
echo "  Firewall          : active  (ufw status)"
echo ""
warn "Open a NEW terminal and verify SSH key login works BEFORE closing this session."