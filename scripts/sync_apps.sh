#!/bin/bash
# Oedon Sync Engine - Atomic Rollback Version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APPS_LIST="${PROJECT_DIR}/apps.list"
DEPLOY="${SCRIPT_DIR}/deploy.sh"
NGINX_CONF_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"
TMP_BACKUP="/tmp/oedon_nginx_bak"

# Source and export .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

source "${SCRIPT_DIR}/preflight.sh"
if ! oedon_validate_apps_list; then
    echo "[ERR] apps.list validation failed. Aborting sync."
    exit 1
fi

mkdir -p "$TMP_BACKUP" "$NGINX_CONF_DIR"

echo "[INFO] Oedon: Synchronizing state..."

# 1. Backup current stable state
cp "$NGINX_CONF_DIR"/*.conf "$TMP_BACKUP/" 2>/dev/null || true

# 2. Generate new config from apps.list
while IFS='|' read -r name port subdomain || [ -n "$name" ]; do
    [[ "$name" =~ ^[[:space:]]*# || -z "${name// }" ]] && continue
    name=$(echo "$name" | xargs)
    port=$(echo "$port" | xargs)
    subdomain=$(echo "$subdomain" | xargs)

    full_domain="${subdomain}.${DOMAIN}"
    bash "$DEPLOY" "$name" "$port" "$full_domain"
done < "$APPS_LIST"

# 3. Validate before applying
if docker exec oedon-proxy nginx -t > /dev/null 2>&1; then
    docker exec oedon-proxy nginx -s reload
    echo "[OK] Infrastructure updated and reloaded."
    rm -rf "$TMP_BACKUP"/*
else
    echo "[ERR] Invalid configuration detected. Rolling back..."
    rm -rf "$NGINX_CONF_DIR"/*.conf
    cp "$TMP_BACKUP"/*.conf "$NGINX_CONF_DIR/"
    docker exec oedon-proxy nginx -s reload
    echo "[WARN] Restored last stable configuration."
    exit 1
fi
