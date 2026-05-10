#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Install required packages
sudo apt update
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https

# Add Caddy GPG key
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

# Add Caddy repository
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

# Update package lists
sudo apt update

# Install Caddy
sudo apt install -y caddy

# Verify installation
caddy version


