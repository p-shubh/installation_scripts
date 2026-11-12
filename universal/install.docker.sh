
#!/usr/bin/env bash

# =============================================================================
# Docker Engine Installation Script
# Supports Ubuntu 24.04+ and supported Ubuntu releases.
# Installs Docker Engine, Buildx and Docker Compose Plugin.
# =============================================================================

set -Eeuo pipefail

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

trap 'error "Installation failed at line $LINENO. Exit code: $?"' ERR

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    error "Run this script as root: sudo bash install.docker.sh"
fi

if [[ ! -f /etc/os-release ]]; then
    error "Cannot identify operating system."
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    error "This script supports Ubuntu only."
fi

ARCH=$(dpkg --print-architecture)
CODENAME="${VERSION_CODENAME:-}"

if [[ -z "$CODENAME" ]]; then
    error "Unable to determine Ubuntu release codename."
fi

info "Ubuntu version: ${VERSION_ID}"
info "Codename: ${CODENAME}"
info "Architecture: ${ARCH}"

# -----------------------------------------------------------------------------
# Step 1 - Update system and install dependencies
# -----------------------------------------------------------------------------

info "Updating package lists..."

apt-get update

info "Installing required packages..."

apt-get install -y \
    ca-certificates \
    curl

# -----------------------------------------------------------------------------
# Step 2 - Configure Docker GPG key
# -----------------------------------------------------------------------------

info "Adding Docker official GPG key..."

install -m 0755 -d /etc/apt/keyrings

curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

# -----------------------------------------------------------------------------
# Step 3 - Configure Docker repository
# -----------------------------------------------------------------------------

info "Configuring Docker repository..."

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# -----------------------------------------------------------------------------
# Step 4 - Install Docker Engine and plugins
# -----------------------------------------------------------------------------

info "Updating package lists..."

apt-get update

info "Installing Docker Engine, Buildx and Compose..."

apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# -----------------------------------------------------------------------------
# Step 5 - Enable Docker service
# -----------------------------------------------------------------------------

info "Enabling Docker service..."

systemctl enable --now docker

if ! systemctl is-active --quiet docker; then
    error "Docker service is not running."
fi

info "Docker service is running."

# -----------------------------------------------------------------------------
# Step 6 - Verify Docker Engine
# -----------------------------------------------------------------------------

info "Checking Docker Engine..."

docker --version

docker version

# -----------------------------------------------------------------------------
# Step 7 - Verify Docker Compose
# -----------------------------------------------------------------------------

info "Checking Docker Compose..."

docker compose version

# -----------------------------------------------------------------------------
# Step 8 - Verify Docker Buildx
# -----------------------------------------------------------------------------

info "Checking Docker Buildx..."

docker buildx version

# -----------------------------------------------------------------------------
# Step 9 - Test Docker installation
# -----------------------------------------------------------------------------

info "Running Docker hello-world test..."

docker run --rm hello-world

# -----------------------------------------------------------------------------
# Step 10 - Optional non-root Docker access
# -----------------------------------------------------------------------------

if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    warn "Docker can optionally be configured for ${SUDO_USER}."
    warn "The docker group grants root-equivalent privileges."
    warn "To enable it manually, run:"
    echo "  usermod -aG docker ${SUDO_USER}"
    echo "  Then log out and log back in."
fi

# -----------------------------------------------------------------------------
# Final report
# -----------------------------------------------------------------------------

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Docker installation completed successfully${NC}"
echo -e "${GREEN}============================================${NC}"

echo ""
echo "Docker Engine  : $(docker --version)"
echo "Docker Compose : $(docker compose version)"
echo "Docker Buildx  : $(docker buildx version)"
echo "Docker Service : $(systemctl is-active docker)"
echo ""
echo "Useful commands:"
echo "  docker ps"
echo "  docker compose up -d"
echo "  docker compose down"
echo "  docker compose logs -f"
echo ""
