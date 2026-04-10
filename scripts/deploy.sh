#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_DIR}/scripts/colors.sh"

# Source and export .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

# Preflight validation
source "${SCRIPT_DIR}/preflight.sh"

if ! oedon_validate_env; then
    echo -e "${ERR} Environment validation failed. Aborting deploy."
    exit 1
fi

if ! oedon_validate_apps_list; then
    echo -e "${ERR} apps.list validation failed. Aborting deploy."
    exit 1
fi

SITES_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"
mkdir -p "$SITES_DIR"

# Collect deployed domains for hosts file hint
DEPLOYED_DOMAINS=()

deploy_app() {
    local APP_NAME=$1
    local APP_PORT=$2
    local APP_DOMAIN=$3

    DEPLOYED_DOMAINS+=("$APP_DOMAIN")

    if [ "$APP_PORT" = "9000" ]; then
        PROXY_CONFIG="
        resolver 127.0.0.11 valid=30s;
        root /var/www/html;
        index index.php;
        location / { try_files \$uri \$uri/ /index.php?\$args; }
        location ~ \.php\$ {
            set \$upstream ${APP_NAME}:${APP_PORT};
            include fastcgi_params;
            fastcgi_pass \$upstream;
            fastcgi_param SCRIPT_FILENAME /var/www/html\$fastcgi_script_name;
            fastcgi_param HTTPS on;
        }"
    else
        PROXY_CONFIG="
        location / {
            resolver 127.0.0.11 valid=30s;
            set \$upstream http://${APP_NAME}:${APP_PORT};
            proxy_pass \$upstream;
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
    ssl_certificate /etc/nginx/ssl/oedon.crt;
    ssl_certificate_key /etc/nginx/ssl/oedon.key;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    ${PROXY_CONFIG}
}
NGINX
    echo -e "   ${OK} ${APP_DOMAIN} configured"
}

# Resolve full domain from subdomain field
resolve_domain() {
    local subdomain="$1"
    echo "${subdomain}.${DOMAIN}"
}

if [ $# -eq 0 ]; then
    if [ ! -f "${PROJECT_DIR}/apps.list" ]; then
        echo -e "${ERR} apps.list not found."
        exit 1
    fi

    # Step 0: SSL Management
    SSL_DIR="${PROJECT_DIR}/config/nginx/ssl"
    mkdir -p "$SSL_DIR"

    if [ ! -f "${SSL_DIR}/oedon.crt" ] || [ ! -f "${SSL_DIR}/oedon.key" ]; then
        echo -e "${SSL} ${BOLD}Certificate missing. Provisioning SSL...${NC}"

        if [ "${APP_ENV:-local}" = "local" ]; then
            if command -v mkcert >/dev/null 2>&1; then
                echo -e "   ${INFO} Using mkcert for local trusted infrastructure..."
                mkcert -cert-file "${SSL_DIR}/oedon.crt" \
                       -key-file "${SSL_DIR}/oedon.key" \
                       "${DOMAIN}" "*.${DOMAIN}" "localhost" "127.0.0.1" >/dev/null 2>&1

                echo -e "   ${OK} Trusted local certificate generated."
                echo -e "\n${WARN} ${BOLD}${YELLOW}ACTION REQUIRED: BROWSER TRUST${NC}"
                echo -e "${YELLOW}   Copy the Root CA to your host: mkcert -CAROOT${NC}"
                echo -e "   Install it in 'Trusted Root Certification Authorities'.\n"
            else
                echo -e "   ${WARN} mkcert not found. Falling back to self-signed OpenSSL."
                openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout "${SSL_DIR}/oedon.key" \
                    -out "${SSL_DIR}/oedon.crt" \
                    -subj "/CN=${DOMAIN}/O=Oedon/C=ES" 2>/dev/null
                echo -e "   ${OK} Self-signed certificate generated (Untrusted)."
            fi
        else
            echo -e "   ${INFO} Production mode. Running Certbot..."
            bash "${SCRIPT_DIR}/oedon-certbot.sh"
        fi

        chmod 644 "${SSL_DIR}/oedon.crt"
        chmod 600 "${SSL_DIR}/oedon.key"
    fi

    # Step 1: Nginx Configuration
    echo -e "${BLUE}${BOLD}--- CONFIGURING VHOSTS ---${NC}"
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        name=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
        port=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        subdomain=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')
        [[ -z "$name" || -z "$port" || -z "$subdomain" ]] && continue

        full_domain=$(resolve_domain "$subdomain")
        deploy_app "$name" "$port" "$full_domain"
    done < "${PROJECT_DIR}/apps.list"

    # Step 2: Network
    echo -e "\n${BLUE}${BOLD}--- NETWORK CHECK ---${NC}"
    if ! docker network inspect oedon-network >/dev/null 2>&1; then
        docker network create oedon-network
        echo -e "   ${OK} oedon-network created."
    else
        echo -e "   ${INFO} oedon-network is ready."
    fi

    # Step 3: Infrastructure
    echo -e "\n${BLUE}${BOLD}--- STARTING SERVICES ---${NC}"
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" up -d

    # Step 4: Deploy apps
    for app_dir in "${PROJECT_DIR}"/apps/*/; do
        [ -d "$app_dir" ] || continue
        APP_NAME=$(basename "$app_dir")

        [ -L "${app_dir}.env" ] || ln -sf "../../.env" "${app_dir}.env"

        if [ -f "${app_dir}docker-compose.yml" ] || [ -f "${app_dir}docker-compose.yaml" ]; then
            echo -e "   ${INFO} Deploying app: ${BOLD}${APP_NAME}${NC}"
            docker compose -f "${app_dir}"docker-compose.y* up -d
        fi
    done

    # Step 5: Nginx Reload
    echo -e "\n${BLUE}${BOLD}--- SYNCING PROXY ---${NC}"
    sleep 2
    if docker exec oedon-proxy nginx -s reload 2>/dev/null; then
        echo -e "   ${OK} Nginx reloaded successfully."
    else
        echo -e "   ${ERR} Nginx reload failed. Check logs."
    fi

    # Step 6: Status
    echo -e "\n${CYAN}${BOLD}DEPLOYMENT SUMMARY:${NC}"
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo -e "\n${GREEN}${BOLD}[SUCCESS] Infrastructure is up and running.${NC}"

    # Step 7: Local environment hosts hint
    if [ "${APP_ENV:-local}" = "local" ] && [ ${#DEPLOYED_DOMAINS[@]} -gt 0 ]; then
        # Detect server IP
        SERVER_IP=$(hostname -I | awk '{print $1}')

        echo -e "\n${YELLOW}${BOLD}--- LOCAL ENVIRONMENT: HOSTS FILE ---${NC}"
        echo -e "${YELLOW}Add these lines to your hosts file to access your sites:${NC}"
        echo -e "${CYAN}   Windows: C:\\Windows\\System32\\drivers\\etc\\hosts${NC}"
        echo -e "${CYAN}   Linux/Mac: /etc/hosts${NC}\n"
        for domain in "${DEPLOYED_DOMAINS[@]}"; do
            echo -e "   ${SERVER_IP}    ${domain}"
        done
        echo ""
    fi

elif [ $# -eq 3 ]; then
    # Direct call: deploy_app name port full_domain
    deploy_app "$1" "$2" "$3"
else
    echo -e "${ERR} Usage: oedon deploy"
    exit 1
fi
