#!/usr/bin/env bash

set -e

CONTAINER_NAME="netsepio-ipfs"

echo "🔍 Checking if container already exists..."

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "🧹 Removing existing container: ${CONTAINER_NAME}"
  docker rm -f ${CONTAINER_NAME}
fi

echo "🚀 Starting IPFS container..."

docker run -d \
  --name netsepio-ipfs \
  --network netsepio_prod_network \
  --restart unless-stopped \
  -p 4001:4001/tcp \
  -p 4001:4001/udp \
  -v ipfs_volume:/data/ipfs \
  -e IPFS_AUTO_TLS=false \
  -e IPFS_PROFILE=server \
  -l "traefik.enable=true" \
  -l "traefik.http.services.ipfs-gateway.loadbalancer.server.port=8080" \
  -l "traefik.http.services.ipfs-api.loadbalancer.server.port=5001" \
  -l "traefik.http.routers.ipfs.rule=Host(\`ipfs.erebrus.io\`)" \
  -l "traefik.http.routers.ipfs.entrypoints=websecure" \
  -l "traefik.http.routers.ipfs.tls=true" \
  -l "traefik.http.routers.ipfs.tls.certresolver=letsencrypt" \
  -l "traefik.http.routers.ipfs.service=ipfs-gateway" \
  -l "traefik.http.routers.ipfs.priority=10" \
  -l "traefik.http.routers.ipfs-path.rule=Host(\`ipfs.erebrus.io\`) && PathPrefix(\`/ipfs\`)" \
  -l "traefik.http.routers.ipfs-path.entrypoints=websecure" \
  -l "traefik.http.routers.ipfs-path.tls=true" \
  -l "traefik.http.routers.ipfs-path.tls.certresolver=letsencrypt" \
  -l "traefik.http.routers.ipfs-path.service=ipfs-gateway" \
  -l "traefik.http.routers.ipfs-path.priority=20" \
  -l "traefik.http.routers.ipfs-api.rule=Host(\`ipfs.erebrus.io\`) && PathPrefix(\`/api\`)" \
  -l "traefik.http.routers.ipfs-api.entrypoints=websecure" \
  -l "traefik.http.routers.ipfs-api.tls=true" \
  -l "traefik.http.routers.ipfs-api.tls.certresolver=letsencrypt" \
  -l "traefik.http.routers.ipfs-api.service=ipfs-api" \
  -l "traefik.http.routers.ipfs-api.priority=100" \
  ipfs/kubo:latest

echo "✅ IPFS container started successfully"
