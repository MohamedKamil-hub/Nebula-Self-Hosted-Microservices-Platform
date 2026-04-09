#!/bin/bash
# scripts/generate_certs.sh — Oedon SSL Manager
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="${PROJECT_DIR}/config/nginx/ssl"
mkdir -p "$SSL_DIR"

# Load environment
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"
DOMAIN="${DOMAIN:-oedon.test}"

echo "========================================"
echo "      OEDON SSL GENERATOR"
echo "========================================"

echo "Choose your certificate environment:"
echo "1) Local Development (Trustworthy with mkcert)"
echo "2) Production (Let's Encrypt / Certbot)"
read -p "Selection [1-2]: " ENV_CHOICE

case $ENV_CHOICE in
    1)
        if ! command -v mkcert >/dev/null 2>&1; then
            echo ""
            echo "❌ ERROR: 'mkcert' is not installed."
            echo "To maintain Oedon's professional standards, we don't use untrusted certificates."
            echo "Please install it: 'sudo apt install mkcert' and run 'mkcert -install'"
            exit 1
        fi

        echo "[*] Generating trusted local certificates for ${DOMAIN}..."
        mkcert -cert-file "${SSL_DIR}/oedon.crt" \
               -key-file "${SSL_DIR}/oedon.key" \
               "${DOMAIN}" "*.${DOMAIN}" "localhost" "127.0.0.1"
        
        echo ""
        echo "✅ SUCCESS: Local certificates generated."
        echo "📍 Path: ${SSL_DIR}"
        echo "💡 IMPORTANT: Copy the Root CA to your host machine to get the green lock."
        echo "   You can find it by running: 'mkcert -CAROOT'"
        ;;

    2)
        echo "[*] Production mode selected."
        echo "This requires port 80 to be open and a real domain pointing to this IP."
        read -p "Continue with Certbot? (y/n): " CONFIRM
        if [ "$CONFIRM" == "y" ]; then
            bash "${SCRIPT_DIR}/oedon-certbot.sh"
        else
            echo "Aborted."
            exit 0
        fi
        ;;

    *)
        echo "Invalid selection. Exiting."
        exit 1
        ;;
esac

# Final Permissions
chmod 644 "${SSL_DIR}/oedon.crt" 2>/dev/null || true
chmod 600 "${SSL_DIR}/oedon.key" 2>/dev/null || true
