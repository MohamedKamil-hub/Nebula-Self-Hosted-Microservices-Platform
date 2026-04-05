#!/bin/bash
# ./scripts/06-setup-fail2ban.sh
# OEDON - Fail2Ban Configuration
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Load .env ───────────────────────────────────────────
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

SSH_PORT="${SSH_PORT:-2222}"
NGINX_LOG_PATH="${PROJECT_DIR}/logs/nginx"

echo "=== OEDON FAIL2BAN CONFIGURATION ==="

# 1. Install
sudo apt update
sudo apt install -y fail2ban

sudo mkdir -p /etc/fail2ban/jail.d

# 2. SSH jail
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1
banaction = ufw

[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

# 3. Nginx jail
sudo tee /etc/fail2ban/jail.d/nginx.local > /dev/null <<EOF
[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = ${NGINX_LOG_PATH}/error.log
maxretry = 3
bantime = 600
EOF

# 4. Enable & restart
sudo systemctl enable --now fail2ban
sleep 3

sudo fail2ban-client status
sudo fail2ban-client status sshd || echo "SSH jail not yet active"

echo "------------------------------------------------"
echo " Fail2Ban configured."
echo " SSH port: ${SSH_PORT}"
echo " Nginx logs: ${NGINX_LOG_PATH}"
echo "------------------------------------------------"

