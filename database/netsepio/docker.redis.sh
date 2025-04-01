#!/bin/bash

# Set environment variables
NETWORK_NAME=netsepio_prod_network
REDIS_CONTAINER_NAME=redis
REDIS_PORT=6379

# Ensure the Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Run Redis container
docker run -d \
    --name $REDIS_CONTAINER_NAME \
    --network=$NETWORK_NAME \
    -p $REDIS_PORT:6379 \
    redis:latest

echo "Redis container is up and running on port $REDIS_PORT."
