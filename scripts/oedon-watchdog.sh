#!/bin/bash
# oedon-watchdog.sh - Self-healing & alert system
# Author: Mohamed Kamil El Kouarti

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source colors (No emojis here)
source "${SCRIPT_DIR}/colors.sh"

# Source and export .env
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo -e "${ERR} TELEGRAM_TOKEN or TELEGRAM_CHAT_ID not set in .env"
    exit 1
fi

# Thresholds
DISK_THRESHOLD="${WATCHDOG_DISK_THRESHOLD:-85}"
MEM_THRESHOLD="${WATCHDOG_MEM_THRESHOLD:-90}"
LOAD_THRESHOLD="${WATCHDOG_LOAD_THRESHOLD:-$(nproc)}"

# Cooldown logic
COOLDOWN_DIR="${WATCHDOG_COOLDOWN_DIR:-/tmp/oedon-watchdog}"
COOLDOWN_MINUTES="${WATCHDOG_COOLDOWN_MIN:-30}"
mkdir -p "$COOLDOWN_DIR"

in_cooldown() {
    local key="$1"
    local file="${COOLDOWN_DIR}/${key}"
    if [ -f "$file" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$file") ))
        if [ "$age" -lt $((COOLDOWN_MINUTES * 60)) ]; then return 0; fi
    fi
    return 1
}

set_cooldown() { touch "${COOLDOWN_DIR}/${1}"; }

send_alert() {
    local message="$1"
    local key="$2"
    if in_cooldown "$key"; then return; fi
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" -d parse_mode="Markdown" -d text="$message" > /dev/null 2>&1
    set_cooldown "$key"
}

HOST=$(hostname)
TELEGRAM_ALERTS=""
TERMINAL_LOGS=""
RECOVERY_NEEDED=false

# Check 1: Disk
DISK_PCT=$(df / | awk 'NR==2{gsub("%",""); print $5}')
if [ "$DISK_PCT" -ge "$DISK_THRESHOLD" ]; then
    TELEGRAM_ALERTS="${TELEGRAM_ALERTS}🔴 *Disk* at ${DISK_PCT}% (limit: ${DISK_THRESHOLD}%)\n"
    TERMINAL_LOGS="${TERMINAL_LOGS}[DISK] usage: ${DISK_PCT}%\n"
fi

# Check 2: Memory
MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEM_USED=$(free -m  | awk 'NR==2{print $3}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
if [ "$MEM_PCT" -ge "$MEM_THRESHOLD" ]; then
    TELEGRAM_ALERTS="${TELEGRAM_ALERTS}🔴 *Memory* at ${MEM_PCT}% (${MEM_USED}/${MEM_TOTAL} MB)\n"
    TERMINAL_LOGS="${TERMINAL_LOGS}[MEM] usage: ${MEM_PCT}%\n"
fi

# Check 3: Docker Containers (SELF-HEALING)
if command -v docker &>/dev/null; then
    EXPECTED_CONTAINERS="${WATCHDOG_CONTAINERS:-oedon-proxy oedon-static wordpress-db wordpress-app python-app}"
    for container in $EXPECTED_CONTAINERS; do
        if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            TELEGRAM_ALERTS="${TELEGRAM_ALERTS}🔴 *Container Down:* \`${container}\`\n"
            TERMINAL_LOGS="${TERMINAL_LOGS}[DOWN] ${container}\n"
            RECOVERY_NEEDED=true
        fi
    done
fi

# Execution of Recovery
if [ "$RECOVERY_NEEDED" = true ]; then
    echo -e "${WARN} Anomalies detected. Starting recovery..."
    cd "$PROJECT_DIR" && docker compose up -d > /dev/null 2>&1
    TELEGRAM_ALERTS="${TELEGRAM_ALERTS}⚙️ *Self-healing:* Services restarted.\n"
    TERMINAL_LOGS="${TERMINAL_LOGS}[INFO] Recovery action executed.\n"
fi

# Final Reporting
if [ -n "$TELEGRAM_ALERTS" ]; then
    # Format for Telegram (With Emojis)
    MESSAGE="⚠️ *OEDON WATCHDOG* — \`${HOST}\`

${TELEGRAM_ALERTS}
_$(date '+%Y-%m-%d %H:%M:%S')_"
    
    ALERT_KEY=$(echo "$TELEGRAM_ALERTS" | md5sum | cut -d' ' -f1)
    send_alert "$MESSAGE" "$ALERT_KEY"
    
    # Format for Terminal (No Emojis, Just Colors)
    echo -e "${ERR} Issues found. Log summary:"
    echo -e "${TERMINAL_LOGS}"
else
    echo -e "${OK} All checks passed - $(date '+%H:%M:%S')"
fi
