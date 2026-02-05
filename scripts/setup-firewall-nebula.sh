#!/bin/bash
# scripts/setup-firewall-nebula.sh
# NEBULA - Firewall Configuration Script

echo "=== NEBULA FIREWALL CONFIGURATION ==="

# 1. Reset and policies
# Resets existing rules to avoid conflicts
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2. Main rules
echo "Configuring rules..."

# SSH Brute-force protection
sudo ufw limit 2222/tcp comment 'SSH protected (6 tries/30s)'

# Web & Service ports
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 19999/tcp comment 'Netdata'
sudo ufw allow 81/tcp comment 'Nginx PM'

# 3. Activate firewall
sudo ufw --force enable

echo "------------------------------------------------"
echo "✅ Firewall configured and enabled."
echo "⚠️  CAUTION: If you fail 6 times in 30s via SSH, your IP will be limited."
echo "💡 For development, you can use 'sudo ufw allow 2222/tcp' to disable limits."
echo "------------------------------------------------"

sudo ufw status numbered
