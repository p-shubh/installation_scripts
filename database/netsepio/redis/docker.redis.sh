#!/bin/bash

# Set environment variables
NETWORK_NAME=netsepio_prod_network
REDIS_CONTAINER_NAME=redis
REDIS_PORT=6379
REDIS_VOLUME_NAME=redis_data_volume
REDIS_CONFIG_PATH=/opt/redis/redis.conf
REDIS_PASSWORD=I9061U6286QJCPN0M

# Ensure config directory exists
mkdir -p /opt/redis

# Write secure standalone Redis config
cat <<EOF > $REDIS_CONFIG_PATH
replicaof no one
requirepass $REDIS_PASSWORD
EOF

# Ensure Docker network exists
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Remove any existing Redis container and volume
docker rm -f $REDIS_CONTAINER_NAME 2>/dev/null
docker volume rm $REDIS_VOLUME_NAME 2>/dev/null

# Create fresh volume
docker volume create $REDIS_VOLUME_NAME
echo "Created Docker volume $REDIS_VOLUME_NAME."

# Run Redis container with custom config and password
docker run -d \
    --name $REDIS_CONTAINER_NAME \
    --network=$NETWORK_NAME \
    -p $REDIS_PORT:6379 \
    -v $REDIS_VOLUME_NAME:/data \
    -v $REDIS_CONFIG_PATH:/usr/local/etc/redis/redis.conf \
    --restart unless-stopped \
    redis:latest \
    redis-server /usr/local/etc/redis/redis.conf

echo "Redis is running in secured standalone mode with password authentication and persistent volume."
