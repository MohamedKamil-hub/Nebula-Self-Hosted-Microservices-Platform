#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

NGINX_LOG_PATH="${PROJECT_DIR}/logs/nginx"

echo "=== OEDON FAIL2BAN CONFIGURATION ==="

mkdir -p /etc/fail2ban/jail.d

# Global defaults — no SSH, no app-specific jails
tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8
banaction = ufw

# SSH intentionally not managed here — configure manually if needed
[sshd]
enabled = false
EOF

# Single scalable Nginx jail — reads ALL nginx logs via wildcard
# Covers any app added to apps.list automatically (wordpress, moodle, prestashop, etc.)
tee /etc/fail2ban/jail.d/oedon-nginx.local > /dev/null << EOF
[nginx-http-auth]
enabled  = true
port     = http,https
filter   = nginx-http-auth
logpath  = ${NGINX_LOG_PATH}/*.log
maxretry = 3
bantime  = 3600

[nginx-botscan]
enabled  = true
port     = http,https
filter   = nginx-botscan
logpath  = ${NGINX_LOG_PATH}/*.log
maxretry = 5
bantime  = 86400
EOF

# nginx-botscan filter — catches common scanners, wp-login brute force, etc.
tee /etc/fail2ban/filter.d/nginx-botscan.conf > /dev/null << 'EOF'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*?(wp-login\.php|xmlrpc\.php|\.env|\.git|admin|setup\.php|install\.php|config\.php) .*" (403|404|429|444) .*$
            ^<HOST> .* "(GET|POST|HEAD) .*" 400 .*$
ignoreregex =
EOF

systemctl enable fail2ban
systemctl restart fail2ban
sleep 2

fail2ban-client status

echo "------------------------------------------------"
echo " Fail2Ban configured."
echo " Nginx logs watched: ${NGINX_LOG_PATH}/*.log"
echo " All apps added via 'oedon add' are protected automatically."
echo "------------------------------------------------"
