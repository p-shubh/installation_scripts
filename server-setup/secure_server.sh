#!/bin/bash

set -e

echo "🔐 Starting Server Hardening..."

# ----------------------------
# 1. Install Fail2Ban if missing
# ----------------------------
if command -v fail2ban-server >/dev/null 2>&1; then
    echo "✅ Fail2Ban already installed"
else
    echo "📦 Installing Fail2Ban..."
    sudo apt update
    sudo apt install -y fail2ban
fi

# ----------------------------
# 2. Configure Fail2Ban
# ----------------------------
echo "⚙️ Configuring Fail2Ban..."

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime  = 24h
findtime = 10m
EOF

sudo systemctl restart fail2ban
sudo systemctl enable fail2ban

echo "✅ Fail2Ban configured"

# ----------------------------
# 3. Secure SSH (Disable Password Login)
# ----------------------------
echo "🔒 Securing SSH..."

sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

sudo systemctl restart ssh

echo "✅ SSH password login disabled"

# ----------------------------
# 4. Verify Services
# ----------------------------
echo "📊 Verifying Fail2Ban status..."
sudo fail2ban-client status sshd || true

echo "🎉 Server hardening complete!"
