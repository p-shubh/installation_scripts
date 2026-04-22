#!/bin/bash
# =============================================================================
#  revert_harden.sh — Reverts all changes made by harden.sh
#  Run as root. Restores SSH config, removes Fail2ban, disables UFW.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()    { echo -e "\n${CYAN}━━━ $* ━━━${NC}"; }

[[ $EUID -ne 0 ]] && error "Run this script as root."

# =============================================================================
#  CONFIRM
# =============================================================================
echo ""
echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}║        ⚠  REVERT HARDENING SCRIPT  ⚠        ║${NC}"
echo -e "${RED}║                                              ║${NC}"
echo -e "${RED}║  This will:                                  ║${NC}"
echo -e "${RED}║  • Restore original sshd_config              ║${NC}"
echo -e "${RED}║  • Re-enable password authentication         ║${NC}"
echo -e "${RED}║  • Remove Fail2ban                           ║${NC}"
echo -e "${RED}║  • Disable and reset UFW firewall            ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
echo ""
read -rp "Type YES to confirm revert: " confirm
[[ "$confirm" != "YES" ]] && { echo "Aborted."; exit 0; }

# =============================================================================
#  STEP 1 — Restore sshd_config from backup
# =============================================================================
step "Restoring SSH configuration"

SSHD_CONFIG="/etc/ssh/sshd_config"
LATEST_BACKUP=$(ls -t "${SSHD_CONFIG}.bak."* 2>/dev/null | head -n1 || true)

if [[ -n "$LATEST_BACKUP" ]]; then
    cp "$LATEST_BACKUP" "$SSHD_CONFIG"
    info "Restored from backup: $LATEST_BACKUP"
else
    warn "No backup found. Manually reverting key settings to Ubuntu defaults…"

    apply_sshd_setting() {
        local key="$1" val="$2"
        if grep -qE "^#?\s*${key}\s" "$SSHD_CONFIG"; then
            sed -i "s|^#\?\s*${key}\s.*|${key} ${val}|" "$SSHD_CONFIG"
        else
            echo "${key} ${val}" >> "$SSHD_CONFIG"
        fi
    }

    apply_sshd_setting "PermitRootLogin"                 "yes"
    apply_sshd_setting "PasswordAuthentication"          "yes"
    apply_sshd_setting "PubkeyAuthentication"            "yes"
    apply_sshd_setting "AuthenticationMethods"           "any"
    apply_sshd_setting "ChallengeResponseAuthentication" "yes"
    apply_sshd_setting "KbdInteractiveAuthentication"    "yes"
    apply_sshd_setting "UsePAM"                          "yes"
    apply_sshd_setting "PermitEmptyPasswords"            "no"
    apply_sshd_setting "X11Forwarding"                   "yes"
    apply_sshd_setting "AllowAgentForwarding"            "yes"
    apply_sshd_setting "AllowTcpForwarding"              "yes"
    apply_sshd_setting "MaxAuthTries"                    "6"
    apply_sshd_setting "LoginGraceTime"                  "120"
    apply_sshd_setting "ClientAliveInterval"             "0"
    apply_sshd_setting "ClientAliveCountMax"             "3"

    info "SSH settings reverted to Ubuntu defaults manually."
fi

# Validate and restart
sshd -t || error "sshd_config validation failed after revert. Check $SSHD_CONFIG manually."
systemctl restart sshd
info "SSH restarted."

# Clean up backup files
rm -f "${SSHD_CONFIG}.bak."* && info "Backup files removed."

# =============================================================================
#  STEP 2 — Remove Fail2ban
# =============================================================================
step "Removing Fail2ban"

if command -v fail2ban-client &>/dev/null; then
    # Unban all IPs first
    fail2ban-client unban --all 2>/dev/null || true
    info "All banned IPs released."

    systemctl stop fail2ban 2>/dev/null || true
    systemctl disable fail2ban 2>/dev/null || true
    apt-get remove --purge -y -qq fail2ban
    apt-get autoremove -y -qq
    rm -f /etc/fail2ban/jail.local
    info "Fail2ban removed."
else
    info "Fail2ban not installed — skipping."
fi

# =============================================================================
#  STEP 3 — Disable UFW
# =============================================================================
step "Disabling UFW firewall"

if command -v ufw &>/dev/null; then
    ufw --force reset
    ufw disable
    info "UFW disabled and rules reset."
else
    info "UFW not installed — skipping."
fi

# =============================================================================
#  DONE
# =============================================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Revert complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo "  SSH config        : restored to pre-hardening state"
echo "  Password auth     : re-enabled"
echo "  Fail2ban          : removed"
echo "  UFW               : disabled"
echo ""
warn "Your server is now in its original unhardened state."