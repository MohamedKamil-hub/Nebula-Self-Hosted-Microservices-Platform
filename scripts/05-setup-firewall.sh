#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

echo "=== OEDON FIREWALL CONFIGURATION ==="

# Validate PORTERO_UDP_PORT is a number
if [[ ! "${PORTERO_UDP_PORT:-}" =~ ^[0-9]+$ ]]; then
    echo "[WARN] Invalid or missing PORTERO_UDP_PORT. Falling back to 62201."
    PORTERO_PORT=62201
else
    PORTERO_PORT="${PORTERO_UDP_PORT}"
fi

# Disable IPv6
sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw 2>/dev/null || true

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Services
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow "${PORTERO_PORT}"/udp comment 'Oedon Portero Knock'
ufw allow ssh

ufw --force enable
ufw status verbose

echo "------------------------------------------------"
echo " Firewall configured successfully."
echo "------------------------------------------------"
