#!/bin/bash
# Oedon Sync Engine - Atomic Rollback Version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APPS_LIST="${PROJECT_DIR}/apps.list"
DEPLOY="${SCRIPT_DIR}/deploy.sh"
NGINX_CONF_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"
TMP_BACKUP="/tmp/oedon_nginx_bak"

mkdir -p "$TMP_BACKUP"

echo "🔄 Oedon: Sincronizando estado..."

# 1. Backup temporal del estado actual estable
cp "$NGINX_CONF_DIR"/*.conf "$TMP_BACKUP/" 2>/dev/null || true

# 2. Generar nueva configuración basada en apps.list
while IFS='|' read -r name port domain || [ -n "$name" ]; do
    [[ "$name" =~ ^[[:space:]]*# || -z "${name// }" ]] && continue
    name=$(echo "$name" | xargs); port=$(echo "$port" | xargs); domain=$(echo "$domain" | xargs)
    
    bash "$DEPLOY" "$name" "$port" "$domain"
done < "$APPS_LIST"

# 3. Validar INTEGRIDAD antes de aplicar
if docker exec oedon-proxy nginx -t > /dev/null 2>&1; then
    docker exec oedon-proxy nginx -s reload
    echo "✅ Éxito: Infraestructura actualizada y recargada."
    rm -rf "$TMP_BACKUP"/*
else
    echo "❌ ERROR: Configuración inválida detectada. Iniciando Rollback..."
    rm -rf "$NGINX_CONF_DIR"/*.conf
    cp "$TMP_BACKUP"/*.conf "$NGINX_CONF_DIR/"
    docker exec oedon-proxy nginx -s reload
    echo "⚠️  Atención: Se ha restaurado la última configuración estable."
    exit 1
fi
