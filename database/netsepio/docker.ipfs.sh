#!/bin/bash

# Set environment variables
NETWORK_NAME=ipfs_prod_network

# Ensure the Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Run IPFS node container and add treafik labels use domain ipfs.netsepio.com
docker run -d \
    --name="netsepio-ipfs" \
    --network=$NETWORK_NAME \
    -p 4001:4001 \
    -p 5001:5001 \
    -p 8081:8080 \
    ipfs/kubo:latest

echo "IPFS node container is up and running."
