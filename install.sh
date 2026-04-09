#!/bin/bash
# Instalación del Portero Digital Oedon
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

echo "=== Instalando Oedon Portero Digital ==="

# ── Load .env ───────────────────────────────────────────
[ -f "$ENV_FILE" ] || { echo "[!] .env not found in ${SCRIPT_DIR}"; exit 1; }
source "$ENV_FILE"

# ── Validate required vars ──────────────────────────────
if [ -z "${PORTERO_SECRET:-}" ] || [ "$PORTERO_SECRET" = "CHANGE_ME" ]; then
    echo "[!] PORTERO_SECRET not set or still default in .env"
    echo "    Generate one: openssl rand -hex 32"
    exit 1
fi



BASE_DIR=$(pwd)
ln -sf "../../.env" "${BASE_DIR}/apps/wordpress-app/.env"
ln -sf "../../.env" "${BASE_DIR}/apps/python-app/.env"

PORTERO_UDP_PORT="${PORTERO_UDP_PORT:-62201}"
SSH_PORT="${SSH_PORT:-2222}"

# 1. Copiar script y .env
sudo mkdir -p /opt/oedon-portero
sudo cp portero.py /opt/oedon-portero/
sudo cp "$ENV_FILE" /opt/oedon-portero/.env
sudo chmod 700 /opt/oedon-portero/portero.py
sudo chmod 600 /opt/oedon-portero/.env

# 2. Instalar servicio systemd
sudo cp oedon-portero.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable oedon-portero
sudo systemctl restart oedon-portero

# 3. Abrir puerto UDP del portero en UFW
sudo ufw allow "${PORTERO_UDP_PORT}/udp" comment "Oedon Portero Knock"

# 4. Asegurar que SSH NO está abierto por defecto
sudo ufw delete allow "${SSH_PORT}/tcp" 2>/dev/null || true

sudo ufw reload

echo "=== Instalación completa ==="
echo "  UDP knock port: ${PORTERO_UDP_PORT}"
echo "  SSH port:       ${SSH_PORT} (closed by default)"
echo ""
sudo systemctl status oedon-portero --no-pager
echo ""
echo "Logs: sudo journalctl -u oedon-portero -f"
