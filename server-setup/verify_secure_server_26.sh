#!/bin/bash
# =============================================================================
#  verify_secure_server_26.sh — Verifies secure_server_26.sh ran correctly
#  Run as root. Checks SSH drop-in config, Fail2ban, and UFW state.
# =============================================================================

SSH_PORT=22

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
echo -e "${BOLD}   secure_server_26.sh Verification Report${NC}"
echo -e "${BOLD}============================================${NC}"

# =============================================================================
#  1 - SSH KEY
# =============================================================================
section "SSH Authorized Keys"

if [[ -f /root/.ssh/authorized_keys ]] && [[ -s /root/.ssh/authorized_keys ]]; then
    COUNT=$(wc -l < /root/.ssh/authorized_keys)
    ok "authorized_keys exists and has ${COUNT} key(s)"
else
    fail "authorized_keys is missing or empty"
fi

DIR_PERM=$(stat -c "%a" /root/.ssh 2>/dev/null || echo "000")
FILE_PERM=$(stat -c "%a" /root/.ssh/authorized_keys 2>/dev/null || echo "000")
[[ "$DIR_PERM"  == "700" ]] && ok ".ssh directory permissions: 700"         || fail ".ssh directory permissions are ${DIR_PERM} (expected 700)"
[[ "$FILE_PERM" == "600" ]] && ok "authorized_keys permissions: 600"        || fail "authorized_keys permissions are ${FILE_PERM} (expected 600)"

# =============================================================================
#  2 - SSH DROP-IN (99-harden.conf)
# =============================================================================
section "SSH Drop-in Config (99-harden.conf)"

DROPIN="/etc/ssh/sshd_config.d/99-harden.conf"
DROPIN_DIR="/etc/ssh/sshd_config.d"
CLOUD_INIT_CONF="${DROPIN_DIR}/50-cloud-init.conf"

if [[ -f "$DROPIN" ]]; then
    ok "99-harden.conf drop-in exists"
else
    fail "99-harden.conf not found — secure_server_26.sh may not have run"
fi

if grep -qE "^Include.*/sshd_config\.d" /etc/ssh/sshd_config; then
    ok "sshd_config includes sshd_config.d/ directory"
else
    fail "sshd_config does NOT include sshd_config.d/ — drop-in files are being ignored"
fi

# Verify 50-cloud-init.conf no longer has an active PasswordAuthentication line
if [[ -f "$CLOUD_INIT_CONF" ]]; then
    if grep -qE "^[[:space:]]*PasswordAuthentication[[:space:]]" "$CLOUD_INIT_CONF"; then
        fail "50-cloud-init.conf still has an active PasswordAuthentication line — will override 99-harden.conf"
    else
        ok "50-cloud-init.conf: PasswordAuthentication is neutralized (commented out or absent)"
    fi
    # Check for any other conflicting active settings
    if grep -qE "^[[:space:]]*(PermitRootLogin|MaxAuthTries|X11Forwarding|AllowTcpForwarding)[[:space:]]" "$CLOUD_INIT_CONF" 2>/dev/null; then
        warn "50-cloud-init.conf has other active settings that may conflict — review manually"
    else
        ok "50-cloud-init.conf: no other conflicting active settings"
    fi
else
    ok "50-cloud-init.conf not present — no cloud-init conflicts"
fi

# Check for conflicts in any other drop-in (excluding 99-harden.conf itself)
OTHER_CONFLICTS=0
for f in "$DROPIN_DIR"/*.conf; do
    [[ -e "$f" ]]       || continue
    [[ "$f" == "$DROPIN" ]]          && continue
    [[ "$f" == "$CLOUD_INIT_CONF" ]] && continue
    if grep -qE "^[[:space:]]*(PermitRootLogin|PasswordAuthentication|MaxAuthTries|X11Forwarding|AllowTcpForwarding)" "$f" 2>/dev/null; then
        fail "Conflicting active settings in: $(basename "$f")"
        ((OTHER_CONFLICTS++))
    fi
done
[[ $OTHER_CONFLICTS -eq 0 ]] && ok "No conflicting settings in other drop-in files"

# =============================================================================
#  3 - SSH DAEMON EFFECTIVE CONFIG
# =============================================================================
section "SSH Daemon Effective Configuration (sshd -T)"

check_sshd() {
    local key="$1" expected="$2" alt="${3:-}"
    local actual
    actual=$(sshd -T 2>/dev/null | grep -i "^${key} " | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    local exp_lower alt_lower
    exp_lower=$(echo "$expected" | tr '[:upper:]' '[:lower:]')
    alt_lower=$(echo "$alt"      | tr '[:upper:]' '[:lower:]')

    if [[ "$actual" == "$exp_lower" ]] || { [[ -n "$alt_lower" ]] && [[ "$actual" == "$alt_lower" ]]; }; then
        ok "${key}: ${actual}"
    else
        [[ -n "$alt" ]] \
            && fail "${key}: got '${actual}' (expected '${expected}' or '${alt}')" \
            || fail "${key}: got '${actual}' (expected '${expected}')"
    fi
}

check_sshd "permitrootlogin"        "prohibit-password" "without-password"
check_sshd "passwordauthentication" "no"
check_sshd "pubkeyauthentication"   "yes"
check_sshd "permitemptypasswords"   "no"
check_sshd "x11forwarding"          "no"
check_sshd "allowagentforwarding"   "no"
check_sshd "allowtcpforwarding"     "no"
check_sshd "maxauthtries"           "3"

ACTUAL_PORT=$(sshd -T 2>/dev/null | grep "^port " | awk '{print $2}' | head -n1)
[[ "$ACTUAL_PORT" == "$SSH_PORT" ]] \
    && ok "SSH port: ${ACTUAL_PORT}" \
    || fail "SSH port: got '${ACTUAL_PORT}' (expected '${SSH_PORT}')"

BACKUP=$(ls /etc/ssh/sshd_config.bak.* 2>/dev/null | head -n1 || true)
[[ -n "$BACKUP" ]] \
    && ok "sshd_config backup exists: $(basename "$BACKUP")" \
    || warn "No sshd_config backup found"

if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
    ok "sshd service is running"
else
    fail "sshd service is NOT running"
fi

# =============================================================================
#  4 - FAIL2BAN
# =============================================================================
section "Fail2ban"

command -v fail2ban-client &>/dev/null && ok "fail2ban is installed"      || fail "fail2ban is NOT installed"
systemctl is-active  --quiet fail2ban  && ok "fail2ban service is running" || fail "fail2ban service is NOT running"
systemctl is-enabled --quiet fail2ban  && ok "fail2ban is enabled on boot" || warn "fail2ban is not enabled on boot"

if [[ -f /etc/fail2ban/jail.local ]]; then
    ok "jail.local exists"
    grep -q "backend[[:space:]]*=[[:space:]]*systemd" /etc/fail2ban/jail.local \
        && ok "Fail2ban backend: systemd (correct for Ubuntu 26)" \
        || fail "Fail2ban backend is not systemd — will silently fail on Ubuntu 26"
    grep -q "enabled[[:space:]]*=[[:space:]]*true" /etc/fail2ban/jail.local \
        && ok "sshd jail is enabled" \
        || fail "sshd jail does not appear to be enabled"
    BANTIME=$(grep "^bantime" /etc/fail2ban/jail.local | tail -1 | awk -F'=' '{gsub(/ /,"",$2); print $2}')
    ok "bantime: ${BANTIME}"
else
    fail "jail.local not found"
fi

if fail2ban-client status sshd &>/dev/null; then
    BANNED=$(fail2ban-client status sshd | grep "Currently banned" | awk -F':\t' '{print $2}')
    TOTAL=$(fail2ban-client status sshd  | grep "Total banned"     | awk -F':\t' '{print $2}')
    ok "sshd jail active — currently banned: ${BANNED}, total banned: ${TOTAL}"
else
    fail "Could not query fail2ban sshd jail"
fi

# =============================================================================
#  5 - UFW FIREWALL
# =============================================================================
section "UFW Firewall"

command -v ufw &>/dev/null                                                    && ok "ufw is installed"               || fail "ufw is NOT installed"
ufw status | head -1 | grep -q "active"                                       && ok "UFW is active"                  || fail "UFW is NOT active"
ufw status verbose | grep -q "Default: deny (incoming)"                       && ok "Default incoming policy: deny"  || fail "Default incoming policy is NOT deny"
ufw status verbose | grep -q "allow (outgoing)"                               && ok "Default outgoing policy: allow" || fail "Default outgoing policy is NOT allow"
ufw status | grep -qE "^${SSH_PORT}/tcp[[:space:]]+ALLOW"                     && ok "SSH port ${SSH_PORT}/tcp is open" || fail "SSH port ${SSH_PORT}/tcp is NOT open in UFW"

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
    echo -e "${GREEN}  All checks passed. secure_server_26.sh ran successfully.${NC}"
elif [[ $FAIL -eq 0 ]]; then
    echo -e "${YELLOW}  No failures but ${WARN} warning(s). Review above.${NC}"
else
    echo -e "${RED}  ${FAIL} check(s) failed. secure_server_26.sh may not have completed correctly.${NC}"
fi
echo ""
