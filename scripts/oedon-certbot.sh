#!/bin/bash
# oedon-certbot.sh - Obtain or renew Let's Encrypt certificates
# Usage:
#   ./oedon-certbot.sh obtain yourdomain.com
#   ./oedon-certbot.sh renew
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "${PROJECT_DIR}/.env"

ACTION="${1:-help}"
DOMAIN="${2:-}"

case "$ACTION" in
    obtain)
        if [ -z "$DOMAIN" ]; then
            echo "Usage: $0 obtain yourdomain.com"
            exit 1
        fi
        echo "[*] Obtaining certificate for ${DOMAIN}..."
        mkdir -p "${PROJECT_DIR}/data/certbot/www"
        cd "$PROJECT_DIR"
        docker compose run --rm certbot certonly \
            --webroot \
            -w /var/www/certbot \
            -d "$DOMAIN" \
            --email "${CERTBOT_EMAIL:-admin@${DOMAIN}}" \
            --agree-tos \
            --no-eff-email
        echo "[✓] Certificate obtained. Restart nginx:"
        echo "    docker restart oedon-proxy"
        ;;
    renew)
        echo "[*] Renewing certificates..."
        cd "$PROJECT_DIR"
        docker compose run --rm certbot renew
        docker restart oedon-proxy
        echo "[✓] Renewal complete"
        ;;
    *)
        echo "Oedon Certbot Helper"
        echo "  $0 obtain <domain>  - Get new certificate"
        echo "  $0 renew            - Renew all certificates"
        echo ""
        echo "Note: Domain must point to this server's public IP."
        echo "      Currently using self-signed certs for *.${DOMAIN:-oedon.test}"
        ;;
esac
