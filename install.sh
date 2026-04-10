#!/bin/bash
# OEDON - Master Installer
set -e

# Determine script directory reliably
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load colors first
if [ -f "$SCRIPT_DIR/scripts/colors.sh" ]; then
    source "$SCRIPT_DIR/scripts/colors.sh"
else
    # Fallback if colors.sh is missing during first run
    BOLD='' NC='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' 
    OK='[OK]' ERR='[ERR]' INFO='[INFO]' SSL='[SSL]' WARN='[WARN]'
fi

echo -e "${BLUE}${BOLD}--- OEDON MASTER INSTALLATION STARTED ---${NC}"

# 1. Environment & Secrets
echo -e "\n${BLUE}${BOLD}STEP 1: ENVIRONMENT SETUP${NC}"
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "   ${INFO} Creating .env from template..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    bash "$SCRIPT_DIR/scripts/generate-secrets.sh"
    echo -e "   ${OK} Environment secrets generated."
else
    echo -e "   ${OK} .env file already exists."
fi

source "$SCRIPT_DIR/.env"


echo -e "${INFO} Configuring System Guardian (Watchdog)..."
# Add cron job to run every 5 minutes if not exists
(crontab -l 2>/dev/null | grep -v "oedon-watchdog.sh"; echo "*/5 * * * * bash ${SCRIPT_DIR}/scripts/oedon-watchdog.sh") | crontab -
echo -e "   ${OK} Watchdog registered in crontab."

# 2. Dependencies
echo -e "\n${BLUE}${BOLD}STEP 2: SYSTEM DEPENDENCIES${NC}"
echo -e "   ${INFO} Installing Docker Engine..."
bash "$SCRIPT_DIR/scripts/01-install-docker.sh"

echo -e "   ${INFO} Installing security tools (Fail2Ban, UFW)..."
sudo apt-get update -qq
sudo apt-get install -y fail2ban ufw libnss3-tools >/dev/null 2>&1
sudo systemctl enable fail2ban --now >/dev/null 2>&1
echo -e "   ${OK} Security tools installed and enabled."

echo -e "   ${SSL} Provisioning mkcert for trusted local SSL..."
sudo wget -q -O /usr/local/bin/mkcert "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
sudo chmod +x /usr/local/bin/mkcert
mkcert -install >/dev/null 2>&1
echo -e "   ${OK} mkcert initialized."

# 3. CLI Configuration
echo -e "\n${BLUE}${BOLD}STEP 3: CLI CONFIGURATION${NC}"
BIN_SOURCE="$SCRIPT_DIR/bin/oedon"

if [ ! -f "$BIN_SOURCE" ]; then
    echo -e "   ${ERR} Critical error: bin/oedon not found."
    exit 1
fi
chmod +x "$BIN_SOURCE"

echo -e "   ${INFO} Running pre-install binary diagnostics..."
# Explicit cleanup of old 'oedon' binaries
for DIR in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /snap/bin; do
    sudo rm -f "${DIR}/oedon" 2>/dev/null || true
done
sudo rm -f /root/bin/oedon /root/.local/bin/oedon 2>/dev/null || true

# Kill any remaining ghosts outside script dir
sudo find / -xdev -not -path "${SCRIPT_DIR}/*" -name "oedon" \( -type f -o -type l \) -delete 2>/dev/null || true

# Write self-contained wrapper
echo -e "   ${INFO} Creating CLI wrapper in /usr/local/bin/oedon..."
sudo tee /usr/local/bin/oedon > /dev/null << WRAPPER
#!/bin/bash
exec "${BIN_SOURCE}" "\$@"
WRAPPER
sudo chmod +x /usr/local/bin/oedon

# Post-install verification
SUDO_WHICH=$(sudo which oedon 2>/dev/null || echo "NOT FOUND")
if [ "$SUDO_WHICH" == "/usr/local/bin/oedon" ] && sudo oedon help > /dev/null 2>&1; then
    echo -e "   ${OK} 'oedon' CLI command verified and ready."
else
    echo -e "   ${ERR} CLI installation failed. Path: $SUDO_WHICH"
    exit 1
fi

# 4. App Symlinks
echo -e "\n${BLUE}${BOLD}STEP 4: APP ORCHESTRATION${NC}"
echo -e "   ${INFO} Linking environment files to apps..."
ln -sf "../../.env" "$SCRIPT_DIR/apps/wordpress-app/.env"
ln -sf "../../.env" "$SCRIPT_DIR/apps/python-app/.env"
echo -e "   ${OK} Symlinks created successfully."

# 5. Portero Digital Setup
echo -e "\n${BLUE}${BOLD}STEP 5: SECURITY SERVICES (PORTERO)${NC}"
echo -e "   ${INFO} Configuring Port Knocking Daemon..."
sudo mkdir -p /opt/oedon-portero
sudo cp "$SCRIPT_DIR/portero.py" "$SCRIPT_DIR/.env" /opt/oedon-portero/
sudo cp "$SCRIPT_DIR/oedon-portero.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable oedon-portero --now >/dev/null 2>&1
echo -e "   ${OK} Portero service is active."

echo -e "\n${GREEN}${BOLD}--- INSTALLATION COMPLETE ---${NC}"
echo -e "${CYAN}Run 'sudo oedon deploy' to launch your infrastructure.${NC}\n"
