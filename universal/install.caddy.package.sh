#!/usr/bin/env bash

# =============================================================================
# Caddy Package Installation Script
# Installs Caddy natively (not in Docker) from the official Caddy apt
# repository and runs it as the systemd service "caddy".
#
# Supports Debian and Ubuntu.
#
# Email: support@netsepio.com (used as the Let's Encrypt / ACME email)
#
# Usage:
#   sudo bash install.caddy.package.sh
#
# After installation:
#   Config file : /etc/caddy/Caddyfile
#   Reload      : sudo systemctl reload caddy
#   Logs        : sudo journalctl -u caddy -f
# =============================================================================

set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

trap 'rc=$?; error "Installation failed at line ${LINENO} (exit code ${rc})."' ERR

# Email used for Let's Encrypt / ACME account and expiry notices.
# Override with: curl ... | sudo CADDY_EMAIL=you@example.com bash
CADDY_EMAIL="${CADDY_EMAIL:-support@netsepio.com}"
CADDYFILE=/etc/caddy/Caddyfile

KEYRING=/usr/share/keyrings/caddy-stable-archive-keyring.gpg
SOURCE_LIST=/etc/apt/sources.list.d/caddy-stable.list

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    error "Run this script as root: sudo bash install.caddy.package.sh"
fi

if [[ ! -f /etc/os-release ]]; then
    error "Cannot identify operating system."
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
    error "This script supports Debian and Ubuntu only."
fi

info "OS: ${PRETTY_NAME:-$ID}"
info "Architecture: $(dpkg --print-architecture)"

# Caddy binds ports 80 and 443. Warn if something else (for example the
# Docker-based Caddy from install.caddy.sh) already holds them.
PORT_USERS=$(ss -ltnpH '( sport = :80 or sport = :443 )' 2>/dev/null || true)
if [[ -n "$PORT_USERS" ]] && ! grep -q '"caddy"' <<<"$PORT_USERS"; then
    warn "Ports 80/443 are already in use:"
    echo "$PORT_USERS"
    warn "The caddy service may fail to start until they are freed."
fi

# -----------------------------------------------------------------------------
# Step 1 - Install dependencies
# -----------------------------------------------------------------------------

info "Updating package lists..."
apt-get update

info "Installing required packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    gnupg

# -----------------------------------------------------------------------------
# Step 2 - Add Caddy repository
# -----------------------------------------------------------------------------

info "Adding Caddy GPG key..."
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
    | gpg --dearmor --yes -o "$KEYRING"
chmod o+r "$KEYRING"

info "Configuring Caddy repository..."
curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
    -o "$SOURCE_LIST"
chmod o+r "$SOURCE_LIST"

# -----------------------------------------------------------------------------
# Step 3 - Install Caddy
# -----------------------------------------------------------------------------

info "Updating package lists..."
apt-get update

info "Installing Caddy..."
DEBIAN_FRONTEND=noninteractive apt-get install -y caddy

# -----------------------------------------------------------------------------
# Step 4 - Set ACME email in Caddyfile global options
# -----------------------------------------------------------------------------

if grep -qE '^[[:space:]]*email[[:space:]]' "$CADDYFILE"; then
    info "Caddyfile already has an email set; leaving it unchanged:"
    grep -E '^[[:space:]]*email[[:space:]]' "$CADDYFILE"
else
    info "Setting ACME email to ${CADDY_EMAIL} in ${CADDYFILE}..."
    cp "$CADDYFILE" "${CADDYFILE}.bak"

    FIRST_LINE=$(grep -vE '^[[:space:]]*(#|$)' "$CADDYFILE" | head -n 1 || true)
    if [[ "$FIRST_LINE" =~ ^[[:space:]]*\{[[:space:]]*$ ]]; then
        # Global options block already exists: add email inside it.
        awk -v email="$CADDY_EMAIL" '
            !done && /^[[:space:]]*\{[[:space:]]*$/ { print; print "    email " email; done=1; next }
            { print }
        ' "${CADDYFILE}.bak" > "$CADDYFILE"
    else
        # No global options block: prepend one.
        {
            printf '{\n    email %s\n}\n\n' "$CADDY_EMAIL"
            cat "${CADDYFILE}.bak"
        } > "$CADDYFILE"
    fi

    if caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1; then
        rm -f "${CADDYFILE}.bak"
    else
        warn "Caddyfile failed validation after adding email; restoring original."
        mv "${CADDYFILE}.bak" "$CADDYFILE"
    fi
fi

# -----------------------------------------------------------------------------
# Step 5 - Enable and verify
# -----------------------------------------------------------------------------

info "Enabling Caddy service..."
systemctl enable caddy >/dev/null 2>&1 || true
systemctl restart caddy || true

sleep 2

if systemctl is-active --quiet caddy; then
    SERVICE_STATE=active
    info "Caddy service is running."
else
    SERVICE_STATE=failed
    warn "Caddy service is not running. Recent logs:"
    journalctl -u caddy -n 20 --no-pager || true
fi

CADDY_VERSION=$(caddy version 2>/dev/null || echo "unknown")

if [[ "$SERVICE_STATE" == active ]]; then
    info "Testing http://localhost ..."
    if curl -fsS -o /dev/null http://localhost; then
        info "Caddy responded on port 80."
    else
        warn "Caddy is running but did not respond on http://localhost."
    fi
fi

echo ""
echo "============================================"
if [[ "$SERVICE_STATE" == active ]]; then
    echo " Caddy installation completed successfully"
else
    echo " Caddy installed, but the service is not running"
fi
echo "============================================"
echo ""
echo "Caddy Version  : ${CADDY_VERSION}"
echo "Caddy Service  : ${SERVICE_STATE}"
echo "Config File    : ${CADDYFILE}"
echo "ACME Email     : $(grep -E '^[[:space:]]*email[[:space:]]' "$CADDYFILE" | awk '{print $2}' | head -n 1 || true)"
echo ""
echo "Useful commands:"
echo "  sudo nano /etc/caddy/Caddyfile"
echo "  sudo caddy validate --config /etc/caddy/Caddyfile"
echo "  sudo systemctl reload caddy"
echo "  sudo systemctl status caddy"
echo "  sudo journalctl -u caddy -f"
echo ""
