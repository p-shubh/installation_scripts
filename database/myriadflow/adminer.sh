#!/bin/bash

# Configuration
ADMINER_CONTAINER_NAME="adminer_myriadflow"
ADMINER_NETWORK="myriadflow_network"  # Same network as PostgreSQL
ADMINER_PORT="62000"

# Step 1: Run Adminer Container
docker run -d \
  --name $ADMINER_CONTAINER_NAME \
  --network $ADMINER_NETWORK \
  -p $ADMINER_PORT:8080 \
  --restart unless-stopped \
  adminer:latest

# Output success message
echo "Adminer is running in the container '$ADMINER_CONTAINER_NAME' on network '$ADMINER_PORT'."
echo "Access Adminer at: http://localhost:$ADMINER_PORT"
