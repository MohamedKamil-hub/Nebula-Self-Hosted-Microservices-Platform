#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

echo "=== OEDON FIREWALL CONFIGURATION ==="

# Disable IPv6 in ufw
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw 2>/dev/null || true

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# HTTP and HTTPS only — SSH is the user's responsibility
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Portero knock port
ufw allow "${PORTERO_UDP_PORT:-62201}"/udp comment 'Oedon Portero Knock'
sudo ufw allow ssh

ufw --force enable
ufw status verbose

echo "------------------------------------------------"
echo " Firewall configured."
echo " NOTE: SSH port is NOT managed here."
echo " Add it manually if needed: sudo ufw allow <port>/tcp"
echo "------------------------------------------------"
