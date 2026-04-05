#!/bin/bash
# scripts/render-nginx.sh - Genera configs de Nginx desde templates
# Lee DOMAIN de .env y renderiza templates/ → sites-enabled/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="${PROJECT_DIR}/config/nginx/templates"
OUTPUT_DIR="${PROJECT_DIR}/config/nginx/sites-enabled"

# Cargar .env
[ -f "${PROJECT_DIR}/.env" ] || { echo "[!] .env not found"; exit 1; }
source "${PROJECT_DIR}/.env"

export DOMAIN="${DOMAIN:?DOMAIN not set in .env}"

echo "[*] Rendering Nginx configs for domain: ${DOMAIN}"

mkdir -p "$OUTPUT_DIR"

# Limpiar configs anteriores generados
rm -f "${OUTPUT_DIR}"/*.conf

# Renderizar cada template
# IMPORTANTE: solo sustituimos ${DOMAIN}, no las variables de Nginx ($host, $remote_addr, etc.)
for template in "${TEMPLATES_DIR}"/*.conf.template; do
    [ -f "$template" ] || continue
    filename=$(basename "$template" .template)
    envsubst '${DOMAIN}' < "$template" > "${OUTPUT_DIR}/${filename}"
    echo "[✓] ${filename}"
done

echo "[✓] All configs rendered in ${OUTPUT_DIR}/"
echo "[i] Restart nginx: docker restart oedon-proxy"
