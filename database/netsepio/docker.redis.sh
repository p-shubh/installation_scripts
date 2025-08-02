#!/bin/bash

# Set environment variables
NETWORK_NAME=netsepio_prod_network
REDIS_CONTAINER_NAME=redis
REDIS_PORT=6379
REDIS_VOLUME_NAME=redis_data_volume
REDIS_CONFIG_PATH=/opt/redis/redis.conf

# Ensure config file exists
mkdir -p /opt/redis
cat <<EOF > $REDIS_CONFIG_PATH
replicaof no one
EOF

# Ensure Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Remove existing container and volume
docker rm -f $REDIS_CONTAINER_NAME 2>/dev/null
docker volume rm $REDIS_VOLUME_NAME 2>/dev/null

# Create fresh volume
docker volume create $REDIS_VOLUME_NAME
echo "Created Docker volume $REDIS_VOLUME_NAME."

# Run Redis with config override
docker run -d \
    --name $REDIS_CONTAINER_NAME \
    --network=$NETWORK_NAME \
    -p $REDIS_PORT:6379 \
    -v $REDIS_VOLUME_NAME:/data \
    -v $REDIS_CONFIG_PATH:/usr/local/etc/redis/redis.conf \
    --restart unless-stopped \
    redis:latest \
    redis-server /usr/local/etc/redis/redis.conf

echo "Redis container is running in standalone mode with persistent volume and custom config."
