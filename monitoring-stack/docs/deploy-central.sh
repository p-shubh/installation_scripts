#!/usr/bin/env bash
###############################################################################
#  deploy-central.sh  –  Bootstrap the central monitoring server
#  Run once on a fresh Ubuntu 22.04 VM.
#  Usage: sudo bash deploy-central.sh
###############################################################################

set -euo pipefail

INSTALL_DIR="/opt/monitoring-stack/central"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/central"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Central Monitoring Server – Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 1. Install Docker ───────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "[1/6] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$SUDO_USER"
  echo "      ✓ Docker installed"
else
  echo "[1/6] Docker already installed – skipping"
fi

# ── 2. Install Docker Compose plugin ────────────────────────────────────────
if ! docker compose version &>/dev/null; then
  echo "[2/6] Installing Docker Compose plugin..."
  sudo apt-get install -y docker-compose-plugin
else
  echo "[2/6] Docker Compose already available – skipping"
fi

# ── 3. Copy files ────────────────────────────────────────────────────────────
echo "[3/6] Copying monitoring stack files to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "$REPO_DIR"/. "$INSTALL_DIR/"
sudo chown -R "$SUDO_USER":"$SUDO_USER" "$INSTALL_DIR"
echo "      ✓ Files copied"

# ── 4. Set up .env ───────────────────────────────────────────────────────────
echo "[4/6] Setting up environment file..."
if [ ! -f "$INSTALL_DIR/.env" ]; then
  cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
  echo ""
  echo "  ⚠️  Please edit $INSTALL_DIR/.env and set:"
  echo "     - GRAFANA_ADMIN_PASSWORD"
  echo "     - TEAMS_WEBHOOK_* URLs"
  echo ""
  read -r -p "  Press Enter to open .env in nano, or Ctrl+C to exit and edit manually..."
  nano "$INSTALL_DIR/.env"
else
  echo "      ✓ .env already exists – skipping"
fi

# ── 5. Validate Prometheus config ────────────────────────────────────────────
echo "[5/6] Validating Prometheus configuration..."
docker run --rm \
  -v "$INSTALL_DIR/prometheus:/etc/prometheus:ro" \
  prom/prometheus:v2.53.1 \
  promtool check config /etc/prometheus/prometheus.yml
echo "      ✓ prometheus.yml is valid"

# ── 6. Start the stack ────────────────────────────────────────────────────────
echo "[6/6] Starting monitoring stack..."
cd "$INSTALL_DIR"
docker compose pull
docker compose up -d

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Monitoring stack is running!"
echo ""
echo "  Grafana:      https://monitoring.mycompany.com"
echo "  Prometheus:   https://prometheus.mycompany.com  (basic auth)"
echo "  Alertmanager: https://alertmanager.mycompany.com (basic auth)"
echo ""
echo "  Check status:  docker compose ps"
echo "  View logs:     docker compose logs -f"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
