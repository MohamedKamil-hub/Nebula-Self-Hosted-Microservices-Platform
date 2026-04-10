#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

NGINX_LOG_PATH="/var/log/oedon/nginx"

echo "=== OEDON FAIL2BAN CONFIGURATION ==="

# Ensure log directory exists with at least one file
mkdir -p "$NGINX_LOG_PATH"
touch "${NGINX_LOG_PATH}/access.log" "${NGINX_LOG_PATH}/error.log"

mkdir -p /etc/fail2ban/jail.d /etc/fail2ban/filter.d

# ── Global config ──
# Disable all default jails, we define our own
# ── Global config ──
TARGET_SSH_PORT="${SSH_PORT:-22}"

tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8
banaction = ufw

[sshd]
enabled = true
port    = ${TARGET_SSH_PORT}
filter  = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF


# ── Nginx jails ──
# backend = polling forces fail2ban to read actual files
# logpath uses wildcard so ANY app writing to /var/log/oedon/nginx/ is covered
tee /etc/fail2ban/jail.d/oedon-nginx.local > /dev/null << EOF
[nginx-auth]
enabled  = true
port     = http,https
filter   = nginx-auth
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 5
findtime = 300
bantime  = 3600

[nginx-botscan]
enabled  = true
port     = http,https
filter   = nginx-botscan
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 3
findtime = 300
bantime  = 86400

[nginx-badbots]
enabled  = true
port     = http,https
filter   = nginx-badbots
logpath  = ${NGINX_LOG_PATH}/access.log
backend  = polling
maxretry = 1
bantime  = 86400
EOF

# ── Filter: brute force on any login page ──
# Catches wp-login, /login, /admin, /user/login (Moodle, Prestashop, Gitea, etc.)
# Triggers on repeated 401/403 or POST to known auth endpoints
tee /etc/fail2ban/filter.d/nginx-auth.conf > /dev/null << 'FILTER'
[Definition]
# Match any POST to common login paths that returns 401, 403, or 429
# Also matches 200 on wp-login (WP returns 200 on failed login)
failregex = ^<HOST> .* "POST .*(wp-login\.php|xmlrpc\.php|/login|/admin|/user/login|/auth|/signin|/api/auth|/account/login).*" (200|401|403|429) .*$
            ^<HOST> .* "POST .*(wp-login\.php|xmlrpc\.php).*" 200 .*$
ignoreregex = ^<HOST> .* "GET .*(\.css|\.js|\.png|\.jpg|\.ico|\.svg|\.woff)" .*$
FILTER

# ── Filter: path scanners ──
# Catches bots probing for .env, .git, setup files, phpMyAdmin, etc.
tee /etc/fail2ban/filter.d/nginx-botscan.conf > /dev/null << 'FILTER'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD) .*(\.env|\.git|/\.well-known/security\.txt|phpmyadmin|/setup\.php|/install\.php|/config\.php|/administrator|/solr|/actuator).*" (403|404|444) .*$
            ^<HOST> .* "(GET|POST|HEAD) .*" 400 .*$
ignoreregex =
FILTER

# ── Filter: bad user agents ──
tee /etc/fail2ban/filter.d/nginx-badbots.conf > /dev/null << 'FILTER'
[Definition]
failregex = ^<HOST> .* ".*" \d+ \d+ ".*" ".*(sqlmap|nikto|nmap|dirbuster|gobuster|masscan|zgrab|python-requests/2\.\d+|Go-http-client|curl/\d).*"$
ignoreregex =
FILTER

# Restart
systemctl enable fail2ban
systemctl restart fail2ban
sleep 2

# Verify
echo ""
fail2ban-client status
echo ""

# Show active jails
for jail in nginx-auth nginx-botscan nginx-badbots; do
    if fail2ban-client status "$jail" >/dev/null 2>&1; then
        echo "   [OK] ${jail} is active"
    else
        echo "   [WARN] ${jail} failed to start — check: journalctl -u fail2ban"
    fi
done

echo ""
echo "------------------------------------------------"
echo " Fail2Ban configured."
echo " Log source: ${NGINX_LOG_PATH}/access.log"
echo " Backend: polling (reads files directly)"
echo " Coverage: any app behind oedon-proxy"
echo "------------------------------------------------"
