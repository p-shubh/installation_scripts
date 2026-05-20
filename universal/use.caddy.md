You want the Caddy install script + a clear guide on how to connect other containers to it for hosting domains. Here's the complete setup:

---

**Script — Install Caddy in Docker:**

```bash
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
```

---

**How to host a domain on another container:**

### Step 1 — Connect your app container to `caddy_web` network

If starting a **new** container:
```bash
docker run -d \
  --name myapp \
  --network caddy_web \    # 👈 this is the key line
  myapp-image:latest
```

If the container **already exists**:
```bash
docker network connect caddy_web myapp
```

---

### Step 2 — Edit the Caddyfile

```bash
nano /opt/caddy/Caddyfile
```

Add your domain block:
```caddy
{
    email admin@yourdomain.com
}

# Your app — Caddy auto-handles HTTPS/SSL for free
app.yourdomain.com {
    reverse_proxy myapp:3000     # container_name:internal_port
}

# Another app on same Caddy
api.yourdomain.com {
    reverse_proxy api_container:8080
}

# WWW redirect
www.yourdomain.com {
    redir https://yourdomain.com{uri} permanent
}
```

---

### Step 3 — Reload Caddy (no downtime)

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

---

### How it works visually:

```
Internet
    │
    ▼
 Port 80/443
    │
 [Caddy Container] ── caddy_web network ──┬── [myapp container :3000]
                                          ├── [api container :8080]
                                          └── [another container :5000]
```

- Caddy is the **only** container exposed to the internet (ports 80/443)
- All app containers are **internal only** — no ports need to be published (`-p`) on them
- SSL certificates are **automatic** via Let's Encrypt as long as your DNS points to the server

---

### Quick reference commands:
```bash
# View logs
docker logs -f caddy

# Check config is valid before reloading
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# Reload after Caddyfile changes
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# See all containers on the caddy_web network
docker network inspect caddy_web
```