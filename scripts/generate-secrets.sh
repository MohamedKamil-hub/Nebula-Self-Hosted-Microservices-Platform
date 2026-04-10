#!/bin/bash
set -euo pipefail

# Path detection
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"

# Load color definitions
if [ -f "${PROJECT_DIR}/scripts/colors.sh" ]; then
    source "${PROJECT_DIR}/scripts/colors.sh"
else
    # Fallback status tags
    BOLD='' NC='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
    OK='[OK]' ERR='[ERR]' INFO='[INFO]' SSL='[SSL]' WARN='[WARN]'
fi

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${ERR} Environment file not found at $ENV_FILE"
    exit 1
fi

generate_hex_secret() {
    openssl rand -hex 32
}

echo -e "${INFO} ${BOLD}Oedon Secret Management System${NC}"
echo "-----------------------------------------------"
echo "1) Fill pending secrets (CHANGE_ME values)"
echo "2) Rotate a specific secret"
echo "3) Rotate all sensitive infrastructure secrets"
read -p "Select an option [1-3]: " opt

case $opt in
    1)
        PENDING_KEYS=$(grep "CHANGE_ME" "$ENV_FILE" | cut -d= -f1)
        if [ -z "$PENDING_KEYS" ]; then
            echo -e "${INFO} No pending secrets found."
        else
            for key in $PENDING_KEYS; do
                key=$(echo "$key" | xargs)
                val=$(generate_hex_secret)
                sed -i "s|^${key}=CHANGE_ME|${key}=${val}|" "$ENV_FILE"
                echo -e "   ${OK} Provisioned $key"
            done
        fi
        ;;
    2)
        EXISTING_KEYS=$(grep "^[^#]*=" "$ENV_FILE" | cut -d= -f1)
        echo ""
        echo "Select the key you want to rotate:"
        select key in $EXISTING_KEYS "Cancel"; do
            if [ "$key" = "Cancel" ] || [ -z "$key" ]; then break; fi
            val=$(generate_hex_secret)
            sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
            echo -e "   ${OK} $key has been rotated."
            break
        done
        ;;
    3)
        echo -e "${RED}${BOLD}CRITICAL ACTION:${NC} This will change all sensitive passwords."
        read -p "Proceed with full rotation? (y/N): " confirm
        if [[ $confirm == [yY] ]]; then
            SENSITIVE_KEYS=$(grep "^[^#]*=" "$ENV_FILE" | cut -d= -f1 | grep -E "PASSWORD|SECRET|TOKEN|KEY")
            for key in $SENSITIVE_KEYS; do
                key=$(echo "$key" | xargs)
                val=$(generate_hex_secret)
                sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
                echo -e "   ${OK} Rotated $key"
            done
            echo -e "${WARN} All sensitive secrets have been updated."
        fi
        ;;
    *)
        echo -e "${ERR} Invalid selection"
        exit 1
        ;;
esac

echo ""
echo -e "${INFO} ${BOLD}NOTICE:${NC} Run 'sudo oedon deploy' to apply changes to the containers."
