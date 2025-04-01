#!/bin/bash

# Set environment variables
NETWORK_NAME=netsepio_prod_network

# Ensure the Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Run Adminer container
docker run -d \
    --name="netsepio-adminer" \
    --network=$NETWORK_NAME \
    -p 8080:8080 \
    adminer:latest

echo "Adminer container is up and running."
