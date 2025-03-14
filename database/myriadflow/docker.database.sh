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
NETWORK_SUBNET="172.18.0.0/16"
NETWORK_GATEWAY="172.18.0.1"
CONTAINER_IP="172.18.0.100"  # Custom container IP

# Step 1: Create Docker Volume
docker volume create $POSTGRES_VOLUME

# Step 2: Create Docker Network with Custom Subnet & Gateway
docker network create \
  --driver bridge \
  --subnet=$NETWORK_SUBNET \
  --gateway=$NETWORK_GATEWAY \
  $POSTGRES_NETWORK

# Step 3: Run PostgreSQL Container with Static IP
docker run -d \
  --name $CONTAINER_NAME \
  --network $POSTGRES_NETWORK \
  --ip $CONTAINER_IP \
  -p $DB_PORT:5432 \
  -e POSTGRES_USER=$DB_USERNAME \
  -e POSTGRES_PASSWORD=$DB_PASSWORD \
  -e POSTGRES_DB=$DB_NAME \
  -v $POSTGRES_VOLUME:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:latest

# Output success message
echo "PostgreSQL is running in the container '$CONTAINER_NAME' on network '$POSTGRES_NETWORK' with subnet '$NETWORK_SUBNET', gateway '$NETWORK_GATEWAY', and IP '$CONTAINER_IP'."
echo "Access PostgreSQL at: postgres://$DB_USERNAME:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME?sslmode=$DB_SSL_MODE"
