#!/bin/bash
set -e

echo "🧹 Starting full Traefik removal..."

# Stop and remove any Traefik container if it exists
if docker ps -a --format '{{.Names}}' | grep -q '^traefik$'; then
  echo "🛑 Stopping and removing Traefik Docker container..."
  docker stop traefik >/dev/null 2>&1 || true
  docker rm -f traefik >/dev/null 2>&1 || true
fi

# Remove Traefik Docker image if present
if docker images --format '{{.Repository}}' | grep -q 'traefik'; then
  echo "🗑️ Removing Traefik Docker image..."
  docker rmi $(docker images traefik -q) >/dev/null 2>&1 || true
fi

# Remove Traefik Docker network if created
if docker network ls --format '{{.Name}}' | grep -q 'traefik'; then
  echo "🔌 Removing Traefik Docker network..."
  docker network rm traefik >/dev/null 2>&1 || true
fi

# Remove volumes related to Traefik
echo "🧾 Removing any Traefik Docker volumes..."
volumes=$(docker volume ls -q | grep traefik || true)
if [ -n "$volumes" ]; then
  docker volume rm $volumes >/dev/null 2>&1 || true
fi

# Remove any Traefik configuration directories
CONFIG_PATHS=(
  "/etc/traefik"
  "/opt/traefik"
  "/usr/local/etc/traefik"
  "/srv/traefik"
)

for path in "${CONFIG_PATHS[@]}"; do
  if [ -d "$path" ]; then
    echo "🗑️ Removing config directory: $path"
    rm -rf "$path"
  fi
done

# Remove systemd service if installed
if systemctl list-unit-files 2>/dev/null | grep -q 'traefik.service'; then
  echo "🧩 Removing systemd Traefik service..."
  systemctl stop traefik >/dev/null 2>&1 || true
  systemctl disable traefik >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/traefik.service
  systemctl daemon-reload
fi

# Remove Traefik binary if installed manually
if [ -f "/usr/local/bin/traefik" ]; then
  echo "🗑️ Removing Traefik binary..."
  rm -f /usr/local/bin/traefik
fi

# Optional Docker prune — requires TTY; skip if piped
if [ -t 0 ]; then
  read -p "🧼 Do you also want to prune unused Docker resources? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    docker system prune -af --volumes
  fi
else
  echo "ℹ️ Skipping Docker prune prompt (non-interactive shell). Run manually if needed:"
  echo "   docker system prune -af --volumes"
fi

echo "✅ Traefik completely removed from your system!"