#!/bin/bash
# OEDON - Master Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🚀 Starting OEDON Installation..."

# 1. Environment & Secrets
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "📝 Creating .env file from template..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    bash "$SCRIPT_DIR/scripts/generate-secrets.sh"
fi

source "$SCRIPT_DIR/.env"

# 2. Dependencies
echo "🐳 Installing Docker Engine..."
bash "$SCRIPT_DIR/scripts/01-install-docker.sh"

# 3. CLI Configuration
echo "🔧 Setting up 'oedon' CLI command..."
sudo ln -sf "$SCRIPT_DIR/bin/oedon" /usr/local/bin/oedon
sudo chmod +x "$SCRIPT_DIR/bin/oedon"

# 4. App Symlinks
echo "🔗 Linking environment files for apps..."
ln -sf "../../.env" "$SCRIPT_DIR/apps/wordpress-app/.env"
ln -sf "../../.env" "$SCRIPT_DIR/apps/python-app/.env"

# 5. Portero Digital Setup
echo "🛡️  Configuring Port Knocking Daemon..."
sudo mkdir -p /opt/oedon-portero
sudo cp portero.py "$SCRIPT_DIR/.env" /opt/oedon-portero/
sudo cp oedon-portero.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable oedon-portero --now

echo "✅ INSTALLATION COMPLETE."
echo "Use 'oedon sync' to deploy your apps or 'oedon secure' to lock the server."
