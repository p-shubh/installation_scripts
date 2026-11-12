#!/usr/bin/env bash
# =============================================================================
# Docker Removal Script
#
# Removes Docker Engine and the Docker packages installed by install.docker.sh.
# By default, Docker images, containers, volumes and configuration data are
# PRESERVED under /var/lib/docker, /var/lib/containerd and /etc/docker.
#
# Usage:
#   sudo bash uninstall.docker.sh
#   sudo bash uninstall.docker.sh --purge-data
#
# WARNING:
#   --purge-data permanently deletes Docker containers, images, volumes,
#   networks and Docker daemon configuration. Back up anything important first.
# =============================================================================

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

trap 'rc=$?; error "Removal failed at line ${LINENO} (exit code ${rc})."' ERR

PURGE_DATA=false

for arg in "$@"; do
    case "$arg" in
        --purge-data)
            PURGE_DATA=true
            ;;
        -h|--help)
            cat <<'EOF'
Usage:
  sudo bash uninstall.docker.sh
      Remove Docker packages and repository configuration.
      Preserve Docker data and daemon configuration.

  sudo bash uninstall.docker.sh --purge-data
      Also permanently delete Docker data and /etc/docker configuration.

This script does not remove shared packages such as curl or ca-certificates.
It does not automatically remove the docker group.
EOF
            exit 0
            ;;
        *)
            error "Unknown argument: $arg (use --help for usage)"
            ;;
    esac
done

if [[ "${EUID}" -ne 0 ]]; then
    error "Run as root: sudo bash uninstall.docker.sh"
fi

echo ""
warn "This will stop Docker and remove installed Docker packages."
if [[ "$PURGE_DATA" == true ]]; then
    warn "--purge-data selected: Docker data and configuration will be DELETED."
else
    info "Docker data will be preserved."
fi

# Stop and disable services if present.
info "Stopping Docker services..."
for service in docker.service docker.socket containerd.service; do
    if systemctl list-unit-files "$service" --no-legend 2>/dev/null | grep -q .; then
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
    fi
done

# Remove only Docker-related packages. Do not autoremove shared dependencies.
PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
    docker-ce-rootless-extras
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman-docker
)

INSTALLED=()
for package in "${PACKAGES[@]}"; do