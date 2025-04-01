#!/bin/bash

# Docker Setup Script for Ubuntu

# Step 1: Update Your System
echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

# Step 2: Install Required Packages
echo "Installing required packages..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Step 3: Add Docker’s Official GPG Key
echo "Adding Docker’s official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Step 4: Set Up the Docker Repository
echo "Setting up Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 5: Install Docker Engine
echo "Installing Docker Engine..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Step 6: Verify the Installation
echo "Verifying Docker installation..."
sudo docker run hello-world

# Step 7: Manage Docker as a Non-Root User (Optional)
echo "Setting up Docker to run as non-root user..."
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

# Verify that you can run docker commands without sudo
echo "Verifying non-root Docker setup..."
docker run hello-world

# Step 8: Enable Docker to Start on Boot
echo "Enabling Docker to start on boot..."
sudo systemctl enable docker

# Step 9: Configure Docker to Use a Remote Repository (Optional)
# Uncomment and configure the following lines if needed
# echo "Configuring Docker to use a remote repository..."
# sudo tee /etc/docker/daemon.json > /dev/null <<EOF
# {
#   "registry-mirrors": ["https://your-mirror.com"]
# }
# EOF
# sudo systemctl restart docker

# Step 10: Install Docker Compose (Optional)
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')" /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose installation
echo "Verifying Docker Compose installation..."
docker-compose --version

echo "Docker setup is complete!"