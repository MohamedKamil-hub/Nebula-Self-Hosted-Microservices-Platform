#!/bin/bash
# Oedon Preflight Validator

_PREFLIGHT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PREFLIGHT_PROJECT_DIR="$(dirname "$_PREFLIGHT_SCRIPT_DIR")"

oedon_validate_env() {
    local ENV_FILE="${_PREFLIGHT_PROJECT_DIR}/.env"

    if [ ! -f "$ENV_FILE" ]; then
        echo "[ERR] .env file not found. Run install.sh first."
        return 1
    fi

    source "$ENV_FILE"

    local REQUIRED_KEYS=(
        DOMAIN
        APP_ENV
        NETWORK_NAME
        SSH_PORT
        HTTP_PORT
        HTTPS_PORT
        PORTERO_UDP_PORT
        PORTERO_SECRET
        PORTERO_WINDOW
        PORTERO_TOLERANCE
        MYSQL_ROOT_PASSWORD
        MYSQL_DATABASE
        MYSQL_USER
        MYSQL_PASSWORD
    )

    # CERTBOT_EMAIL is mandatory in production – Let's Encrypt requires a
    # valid contact address and will refuse to issue a cert without one.
    if [ "${APP_ENV:-}" = "production" ]; then
        REQUIRED_KEYS+=(CERTBOT_EMAIL)
    fi

    local PENDING=()
    for key in "${REQUIRED_KEYS[@]}"; do
        local val="${!key:-}"
        if [ -z "$val" ] || [ "$val" = "CHANGE_ME" ]; then
            PENDING+=("$key")
        fi
    done

    if [ ${#PENDING[@]} -eq 0 ]; then
        return 0
    fi

    echo ""
    echo "[WARN] Found ${#PENDING[@]} unconfigured key(s): ${PENDING[*]}"
    echo ""

    # Give a clear hint when the only missing thing is CERTBOT_EMAIL
    for key in "${PENDING[@]}"; do
        if [ "$key" = "CERTBOT_EMAIL" ]; then
            echo "[INFO] APP_ENV=production requires CERTBOT_EMAIL."
            echo "       Add it to .env:  CERTBOT_EMAIL=you@example.com"
            echo "       Let's Encrypt needs a real address for expiry notices."
            echo ""
        fi
    done

    if [ -t 0 ]; then
        read -p "Configure now? (Y/n): " confirm
        if [[ "$confirm" =~ ^[nN] ]]; then
            echo "[ERR] Fix .env manually, then re-run deploy."
            return 1
        fi
        bash "${_PREFLIGHT_SCRIPT_DIR}/generate-secrets.sh" --provision
    else
        echo "[ERR] Non-interactive shell. Fix .env manually."
        return 1
    fi

    # Re-validate
    source "$ENV_FILE"
    local STILL_PENDING=()
    for key in "${REQUIRED_KEYS[@]}"; do
        local val="${!key:-}"
        if [ -z "$val" ] || [ "$val" = "CHANGE_ME" ]; then
            STILL_PENDING+=("$key")
        fi
    done

    if [ ${#STILL_PENDING[@]} -gt 0 ]; then
        echo ""
        for key in "${STILL_PENDING[@]}"; do
            echo "[ERR] ${key} is still unset."
        done
        echo "[ERR] Fix .env before proceeding."
        return 1
    fi

    return 0
}

oedon_validate_apps_list() {
    local APPS_LIST="${_PREFLIGHT_PROJECT_DIR}/apps.list"

    if [ ! -f "$APPS_LIST" ]; then
        echo "[ERR] apps.list not found."
        return 1
    fi

    local LINE_NUM=0
    local FAILED=0
    while IFS= read -r line || [ -n "$line" ]; do
        LINE_NUM=$((LINE_NUM + 1))
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        local name port subdomain
        name=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
        port=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
        subdomain=$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')

        if [ -z "$name" ] || [ -z "$port" ] || [ -z "$subdomain" ]; then
            echo "[ERR] apps.list line ${LINE_NUM}: malformed entry"
            FAILED=1
            continue
        fi

        if [[ ! "$port" =~ ^[0-9]+$ ]]; then
            echo "[ERR] apps.list line ${LINE_NUM}: port '${port}' is not a number"
            FAILED=1
        fi

        if [[ "$subdomain" == *.* ]]; then
            echo "[WARN] apps.list line ${LINE_NUM}: '${subdomain}' looks like a full domain. Use subdomain only (e.g., 'static' not 'static.oedon.test')"
        fi
    done < "$APPS_LIST"

    return $FAILED
}
