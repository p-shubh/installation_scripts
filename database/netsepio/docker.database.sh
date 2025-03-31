#!/bin/bash

# Set environment variables
DB_USERNAME=admin
DB_PASSWORD=6pKuf9yw4o4FkZIh
DB_NAME=netsepio
DB_PORT=5432
VOLUME_NAME=netsepio_pgdata
NETWORK_NAME=netsepio_prod_network

# Create Docker network if it does not exist
docker network inspect $NETWORK_NAME >/dev/null 2>&1 || \
    docker network create $NETWORK_NAME

echo "Docker network $NETWORK_NAME is ready."

# Create Docker volume if it does not exist
docker volume inspect $VOLUME_NAME >/dev/null 2>&1 || \
    docker volume create $VOLUME_NAME

echo "Docker volume $VOLUME_NAME is ready."

# Run PostgreSQL container
docker run -d \
    --name netsepio_postgres \
    --net=$NETWORK_NAME \
    -e POSTGRES_USER=$DB_USERNAME \
    -e POSTGRES_PASSWORD=$DB_PASSWORD \
    -e POSTGRES_DB=$DB_NAME \
    -p $DB_PORT:5432 \
    -v $VOLUME_NAME:/var/lib/postgresql/data \
    postgres:latest

echo "PostgreSQL container is up and running."
