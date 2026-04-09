#!/bin/bash
set -euo pipefail

APP_NAME=$1
APP_PORT=$2
APP_DOMAIN=$3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_DIR}/.env"
SITES_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"

# Lógica dinámica según el puerto
if [ "$APP_PORT" == "9000" ]; then
    # Plantilla optimizada para PHP-FPM (como tu WordPress actual)
    PROXY_CONFIG="
        root /var/www/html;
        index index.php;
        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }
        location ~ \.php\$ {
            include fastcgi_params;
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_pass ${APP_NAME}:${APP_PORT};
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME /var/www/html\$fastcgi_script_name;
            fastcgi_param HTTPS on;
        }"
else
    # Plantilla optimizada para HTTP (Python, Node, Static)
    PROXY_CONFIG="
        location / {
            proxy_pass http://${APP_NAME}:${APP_PORT};
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }"
fi

cat > "${SITES_DIR}/${APP_NAME}.conf" << NGINX
server {
    listen 80;
    server_name ${APP_DOMAIN};
    location / { return 301 https://\$host\$request_uri; }
}

server {
    listen 443 ssl;
    server_name ${APP_DOMAIN};
    ssl_certificate /etc/nginx/ssl/$(basename "$SSL_CERT");
    ssl_certificate_key /etc/nginx/ssl/$(basename "$SSL_KEY");

    # Cabeceras de seguridad Oedon
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    ${PROXY_CONFIG}
}
NGINX
