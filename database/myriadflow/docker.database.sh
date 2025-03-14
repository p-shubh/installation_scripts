#!/bin/bash

# Configuration
DB_USERNAME="myriadflow"
DB_PASSWORD="myriadflow-postgres"
DB_NAME="postgres"
DB_SSL_MODE="disable"
DB_PORT="5432"
POSTGRES_VOLUME="pg_myriadflow_data"
POSTGRES_NETWORK="myriadflow_network"  # Updated network name
CONTAINER_NAME="pg_myriadflow"

# Step 1: Create Docker Volume
docker volume create $POSTGRES_VOLUME

# Step 2: Create Docker Network (Bridge Mode)
docker network create --driver bridge $POSTGRES_NETWORK

# Step 3: Run PostgreSQL Container
docker run -d \
  --name $CONTAINER_NAME \
  --network $POSTGRES_NETWORK \
  -p $DB_PORT:5432 \
  -e POSTGRES_USER=$DB_USERNAME \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=$DB_NAME \
  -v $POSTGRES_VOLUME:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:latest

# Output success message
echo "PostgreSQL is running in the container '$CONTAINER_NAME' on network '$POSTGRES_NETWORK' with volume '$POSTGRES_VOLUME'."
