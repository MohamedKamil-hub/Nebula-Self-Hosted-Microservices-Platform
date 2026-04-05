#!/bin/bash
# Instalación y configuración de fail2ban para Oedon (WordPress jails)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Load .env ───────────────────────────────────────────
[ -f "${SCRIPT_DIR}/.env" ] && source "${SCRIPT_DIR}/.env"

NGINX_LOG_PATH="${SCRIPT_DIR}/logs/nginx"

echo "=== Instalando fail2ban ==="
sudo apt update && sudo apt install -y fail2ban

echo "=== Creando filtro WordPress ==="
sudo tee /etc/fail2ban/filter.d/wordpress-login.conf > /dev/null << 'EOF'
[Definition]
failregex = ^<HOST> .* "POST /wp-login\.php HTTP/.*" 200
ignoreregex =
EOF

echo "=== Creando filtro xmlrpc ==="
sudo tee /etc/fail2ban/filter.d/wordpress-xmlrpc.conf > /dev/null << 'EOF'
[Definition]
failregex = ^<HOST> .* "POST /xmlrpc\.php HTTP/.*"
ignoreregex =
EOF

echo "=== Creando jail.local ==="
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8 ::1
banaction = ufw

[wordpress-login]
enabled = true
filter = wordpress-login
logpath = ${NGINX_LOG_PATH}/access.log
maxretry = 5
findtime = 300
bantime = 3600

[wordpress-xmlrpc]
enabled = true
filter = wordpress-xmlrpc
logpath = ${NGINX_LOG_PATH}/access.log
maxretry = 2
findtime = 60
bantime = 86400
EOF

echo "=== Iniciando fail2ban ==="
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "=== Estado ==="
sudo fail2ban-client status
echo ""
sudo fail2ban-client status wordpress-login
echo ""
sudo fail2ban-client status wordpress-xmlrpc
