#!/bin/bash

# Set environment variables
NETWORK_NAME=netsepio_prod_network
REDIS_CONTAINER_NAME=redis
REDIS_PORT=6379
REDIS_VOLUME_NAME=redis_data_volume

# Ensure the Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Create the Redis volume if it doesn't exist
if ! docker volume ls --format '{{.Name}}' | grep -q "^${REDIS_VOLUME_NAME}$"; then
    docker volume create $REDIS_VOLUME_NAME
    echo "Created Docker volume $REDIS_VOLUME_NAME."
else
    echo "Docker volume $REDIS_VOLUME_NAME already exists."
fi

# Remove existing Redis container if it's already running
if docker ps -a --format '{{.Names}}' | grep -Eq "^${REDIS_CONTAINER_NAME}\$"; then
    echo "Removing existing Redis container..."
    docker rm -f $REDIS_CONTAINER_NAME
fi

# Run Redis container with volume mounted
docker run -d \
    --name $REDIS_CONTAINER_NAME \
    --network=$NETWORK_NAME \
    -p $REDIS_PORT:6379 \
    -v $REDIS_VOLUME_NAME:/data \
    --restart unless-stopped \
    redis:latest \
    --replicaof "" ""

echo "Redis container is up and running on port $REDIS_PORT with volume $REDIS_VOLUME_NAME for persistent data."
