#!/bin/bash
# ============================================================
# Traefik Core Setup Script for Ubuntu
# Author: Cyrene AI Automation
# Email: support@cyreneai.com
# ============================================================

set -e

TRAEFIK_DIR="/opt/traefik"
EMAIL="support@cyreneai.com"

echo "🚀 Starting Traefik Core Installation..."

# ------------------------------------------------------------
# 1. Update system
# ------------------------------------------------------------
echo "🔧 Updating system..."
sudo apt update -y
sudo apt upgrade -y

# ------------------------------------------------------------
# 2. Install Docker and Docker Compose
# ------------------------------------------------------------
if ! command -v docker &> /dev/null; then
  echo "🐳 Installing Docker..."
  sudo apt install -y ca-certificates curl gnupg lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update -y
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

echo "✅ Docker installed: $(docker --version)"
echo "✅ Docker Compose installed: $(docker compose version)"

# ------------------------------------------------------------
# 3. Create Traefik folder structure
# ------------------------------------------------------------
echo "📁 Creating Traefik directories..."
sudo mkdir -p ${TRAEFIK_DIR}/{data,config}
sudo chmod -R 755 ${TRAEFIK_DIR}

# ------------------------------------------------------------
# 4. Create traefik.yml
# ------------------------------------------------------------
echo "🧾 Creating Traefik configuration..."
cat <<EOF | sudo tee ${TRAEFIK_DIR}/data/traefik.yml > /dev/null
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${EMAIL}
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
EOF

# ------------------------------------------------------------
# 5. Create docker-compose.yml
# ------------------------------------------------------------
echo "🐋 Creating Docker Compose file..."
cat <<EOF | sudo tee ${TRAEFIK_DIR}/docker-compose.yml > /dev/null
version: "3.8"

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    restart: always
    command:
      - "--configFile=/traefik.yml"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./data/traefik.yml:/traefik.yml:ro
      - ./data/acme.json:/letsencrypt/acme.json
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - web

networks:
  web:
    external: false
EOF

# ------------------------------------------------------------
# 6. Create acme.json for SSL storage
# ------------------------------------------------------------
echo "🔐 Preparing SSL storage..."
sudo touch ${TRAEFIK_DIR}/data/acme.json
sudo chmod 600 ${TRAEFIK_DIR}/data/acme.json

# ------------------------------------------------------------
# 7. Start Traefik
# ------------------------------------------------------------
echo "🚀 Starting Traefik..."
cd ${TRAEFIK_DIR}
sudo docker compose up -d

# ------------------------------------------------------------
# 8. Final checks
# ------------------------------------------------------------
echo "✅ Traefik setup completed!"
echo "----------------------------------------------"
echo "📍 Directory: ${TRAEFIK_DIR}"
echo "🌐 Ports: 80 (HTTP), 443 (HTTPS)"
echo "📄 Config file: ${TRAEFIK_DIR}/data/traefik.yml"
echo "🔒 SSL Certificates: ${TRAEFIK_DIR}/data/acme.json"
echo "----------------------------------------------"
echo "You can now deploy your Docker services with labels like:"
echo '  - "traefik.enable=true"'
echo '  - "traefik.http.routers.app.rule=Host(`app.yourdomain.com`)"'
echo '  - "traefik.http.routers.app.entrypoints=websecure"'
echo '  - "traefik.http.routers.app.tls.certresolver=letsencrypt"'
echo "----------------------------------------------"
echo "✨ Traefik is up and running!"
