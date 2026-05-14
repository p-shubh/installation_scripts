#!/bin/bash
set -e

CADDY_DIR="/opt/caddy"
CADDYFILE="$CADDY_DIR/Caddyfile"
NETWORK_NAME="caddy_web"

echo "🚀 Setting up Caddy in Docker..."

mkdir -p "$CADDY_DIR/data" "$CADDY_DIR/config" "$CADDY_DIR/site"

# Create shared network
if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  echo "🔌 Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
fi

# Write default Caddyfile
cat > "$CADDYFILE" <<'EOF'
# Global options
{
    email admin@yourdomain.com   # for Let's Encrypt notifications
}

# ── Add your domains below ──────────────────────────────

# Example 1: Reverse proxy to another Docker container
# api.yourdomain.com {
#     reverse_proxy api_container:3000
# }

# Example 2: Static site
# yourdomain.com {
#     root * /srv
#     file_server
# }

# Example 3: HTTP only (no domain, just IP testing)
:80 {
    respond "Caddy is running! Add your domains to /opt/caddy/Caddyfile"
}
EOF

echo "📄 Caddyfile written to $CADDYFILE"

docker pull caddy:latest

# Remove old container if exists
docker rm -f caddy 2>/dev/null || true

docker run -d \
  --name caddy \
  --restart unless-stopped \
  --network "$NETWORK_NAME" \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v "$CADDYFILE":/etc/caddy/Caddyfile \
  -v "$CADDY_DIR/site":/srv \
  -v "$CADDY_DIR/data":/data \
  -v "$CADDY_DIR/config":/config \
  caddy:latest

echo ""
echo "✅ Caddy is running!"
echo "📁 Caddyfile → $CADDYFILE"
echo "🔧 Reload after editing → docker exec caddy caddy reload --config /etc/caddy/Caddyfile"