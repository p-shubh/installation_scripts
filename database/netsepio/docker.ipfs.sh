#!/bin/bash

# Set environment variables
NETWORK_NAME=netsepio_prod_network

# Ensure the Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Run IPFS node container and add treafik labels use domain ipfs.netsepio.com
docker run -d \
  --name="netsepio-ipfs" \
  --network=$NETWORK_NAME \
  --restart unless-stopped \
  -p 4001:4001/tcp \
  -p 4001:4001/udp \
  -p 127.0.0.1:8081:8080 \
  -p 127.0.0.1:5001:5001 \
  -v ipfs_volume:/data/ipfs \
  -e IPFS_AUTO_TLS=false \
  -e IPFS_PROFILE=server \
  ipfs/kubo:latest

echo "IPFS node container is up and running."
