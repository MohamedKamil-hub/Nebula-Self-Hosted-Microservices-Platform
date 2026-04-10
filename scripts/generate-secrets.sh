#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/.env"

if [ -f "${PROJECT_DIR}/scripts/colors.sh" ]; then
    source "${PROJECT_DIR}/scripts/colors.sh"
else
    BOLD='' NC='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
    OK='[OK]' ERR='[ERR]' INFO='[INFO]' SSL='[SSL]' WARN='[WARN]'
fi

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${ERR} .env not found at $ENV_FILE"
    exit 1
fi

gen_pass() { openssl rand -base64 18 | tr -d '=/+' | head -c 24; }

classify_key() {
    case "$1" in
        PORTERO_SECRET|MYSQL_ROOT_PASSWORD|MYSQL_PASSWORD)
            echo "SECRET" ;;
        TELEGRAM_TOKEN|TELEGRAM_CHAT_ID)
            echo "OPTIONAL" ;;
        DOMAIN|CERTBOT_EMAIL)
            echo "ASK" ;;
        *)
            echo "DEFAULT" ;;
    esac
}

default_for_key() {
    case "$1" in
        APP_ENV)                 echo "local" ;;
        NETWORK_NAME)            echo "oedon-network" ;;
        SSH_PORT)                echo "22" ;;
        HTTP_PORT)               echo "80" ;;
        HTTPS_PORT)              echo "443" ;;
        PORTERO_UDP_PORT)        echo "62201" ;;
        PORTERO_WINDOW)          echo "60" ;;
        PORTERO_TOLERANCE)       echo "2" ;;
        MYSQL_DATABASE)          echo "wordpress" ;;
        MYSQL_USER)              echo "wp_user" ;;
        SSL_CERT)                echo "oedon.crt" ;;
        SSL_KEY)                 echo "oedon.key" ;;
        WATCHDOG_DISK_THRESHOLD) echo "85" ;;
        WATCHDOG_MEM_THRESHOLD)  echo "90" ;;
        WATCHDOG_CONTAINERS)     echo "oedon-proxy,wordpress-app,python-app" ;;
        WATCHDOG_COOLDOWN_DIR)   echo "/tmp/oedon-watchdog" ;;
        WATCHDOG_COOLDOWN_MIN)   echo "30" ;;
        CERTBOT_EMAIL)           echo "admin@example.com" ;;
        DOMAIN)                  echo "oedon.test" ;;
        *)                       echo "" ;;
    esac
}

# ── Core function: provision all CHANGE_ME keys ──
# Can be called directly: bash generate-secrets.sh --provision
provision_pending() {
    local PENDING_KEYS
    PENDING_KEYS=$(grep "=CHANGE_ME" "$ENV_FILE" | cut -d= -f1 | xargs) || true

    if [ -z "$PENDING_KEYS" ]; then
        echo -e "${INFO} No pending CHANGE_ME values."
        return 0
    fi

    echo -e "${INFO} Configuring unset keys...\n"

    for key in $PENDING_KEYS; do
        local category
        category=$(classify_key "$key")

        case "$category" in
            SECRET)
                local val
                val=$(gen_pass)
                sed -i "s|^${key}=CHANGE_ME|${key}=${val}|" "$ENV_FILE"
                echo -e "   ${OK} ${key} -> auto-generated"
                ;;
            DEFAULT)
                local def
                def=$(default_for_key "$key")
                if [ -n "$def" ]; then
                    sed -i "s|^${key}=CHANGE_ME|${key}=${def}|" "$ENV_FILE"
                    echo -e "   ${OK} ${key} -> ${def}"
                else
                    local val
                    val=$(gen_pass)
                    sed -i "s|^${key}=CHANGE_ME|${key}=${val}|" "$ENV_FILE"
                    echo -e "   ${OK} ${key} -> auto-generated"
                fi
                ;;
            ASK)
                local def
                def=$(default_for_key "$key")
                read -p "   Enter ${key} [${def}]: " user_val
                user_val="${user_val:-$def}"
                local escaped_val
                escaped_val=$(printf '%s\n' "$user_val" | sed 's/[&/\]/\\&/g')
                sed -i "s|^${key}=CHANGE_ME|${key}=${escaped_val}|" "$ENV_FILE"
                echo -e "   ${OK} ${key} -> ${user_val}"
                ;;
            OPTIONAL)
                sed -i "s|^${key}=CHANGE_ME|${key}=|" "$ENV_FILE"
                echo -e "   ${INFO} ${key} -> empty (optional)"
                ;;
        esac
    done

    # Auto-detect APP_ENV from DOMAIN
    source "$ENV_FILE"
    if [[ "${DOMAIN:-}" == *".test" ]] || [[ "${DOMAIN:-}" == "localhost" ]]; then
        sed -i "s|^APP_ENV=.*|APP_ENV=local|" "$ENV_FILE"
    elif [[ "${DOMAIN:-}" != "CHANGE_ME" ]] && [[ -n "${DOMAIN:-}" ]]; then
        local current_env
        current_env=$(grep "^APP_ENV=" "$ENV_FILE" | cut -d= -f2)
        if [ "$current_env" = "local" ] || [ "$current_env" = "CHANGE_ME" ]; then
            read -p "   Production domain detected. Set APP_ENV=production? (Y/n): " env_confirm
            if [[ ! "$env_confirm" =~ ^[nN] ]]; then
                sed -i "s|^APP_ENV=.*|APP_ENV=production|" "$ENV_FILE"
                echo -e "   ${OK} APP_ENV -> production"
            fi
        fi
    fi

    echo -e "\n${OK} Configuration complete."
}

rotate_single() {
    local EXISTING_KEYS
    EXISTING_KEYS=$(grep "^[^#]*=" "$ENV_FILE" | cut -d= -f1)
    echo ""
    echo "Select the key to rotate:"
    select key in $EXISTING_KEYS "Cancel"; do
        if [ "$key" = "Cancel" ] || [ -z "$key" ]; then break; fi
        local val
        val=$(gen_pass)
        sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
        echo -e "   ${OK} ${key} rotated."
        break
    done
}

rotate_all_secrets() {
    echo -e "${RED}${BOLD}CRITICAL ACTION:${NC} This will change all sensitive passwords."
    read -p "Proceed with full rotation? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        local SENSITIVE_KEYS
        SENSITIVE_KEYS=$(grep "^[^#]*=" "$ENV_FILE" | cut -d= -f1 | grep -E "PASSWORD|SECRET|TOKEN" | grep -v "OEDON_PUBLIC_KEY") || true
        for key in $SENSITIVE_KEYS; do
            key=$(echo "$key" | xargs)
            local val
            val=$(gen_pass)
            sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
            echo -e "   ${OK} Rotated ${key}"
        done
        echo -e "${WARN} All sensitive secrets updated."
    fi
}

# ── Entry point ──
# --provision : direct call from preflight, no menu
# no args     : interactive menu (for oedon rotate)

if [ "${1:-}" = "--provision" ]; then
    provision_pending
    exit 0
fi

echo -e "${INFO} ${BOLD}Oedon Secret Management System${NC}"
echo "-----------------------------------------------"
echo "1) Fill pending secrets (CHANGE_ME values)"
echo "2) Rotate a specific secret"
echo "3) Rotate all sensitive infrastructure secrets"
read -p "Select an option [1-3]: " opt

case $opt in
    1) provision_pending ;;
    2) rotate_single ;;
    3) rotate_all_secrets ;;
    *) echo -e "${ERR} Invalid selection"; exit 1 ;;
esac

echo ""
echo -e "${INFO} ${BOLD}NOTICE:${NC} Run 'sudo oedon deploy' to apply changes."
