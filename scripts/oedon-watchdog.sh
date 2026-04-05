#!/bin/bash
# oedon-watchdog.sh - Lightweight alert system via Telegram
# Author: Mohamed Kamil El Kouarti
# Runs via cron every 5 minutes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ── Load config from .env ───────────────────────────────
[ -f "${PROJECT_DIR}/.env" ] || { echo "[!] .env not found"; exit 1; }
source "${PROJECT_DIR}/.env"

TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "[!] TELEGRAM_TOKEN or TELEGRAM_CHAT_ID not set in .env"
    exit 1
fi

# ── Thresholds (all from .env) ──────────────────────────
DISK_THRESHOLD="${WATCHDOG_DISK_THRESHOLD:-85}"
MEM_THRESHOLD="${WATCHDOG_MEM_THRESHOLD:-90}"
LOAD_THRESHOLD="${WATCHDOG_LOAD_THRESHOLD:-$(nproc)}"
SSH_PORT="${SSH_PORT:-2222}"

# ── Cooldown (from .env) ────────────────────────────────
COOLDOWN_DIR="${WATCHDOG_COOLDOWN_DIR:-/tmp/oedon-watchdog}"
COOLDOWN_MINUTES="${WATCHDOG_COOLDOWN_MIN:-30}"
mkdir -p "$COOLDOWN_DIR"

in_cooldown() {
    local key="$1"
    local file="${COOLDOWN_DIR}/${key}"
    if [ -f "$file" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$file") ))
        if [ "$age" -lt $((COOLDOWN_MINUTES * 60)) ]; then
            return 0
        fi
    fi
    return 1
}

set_cooldown() {
    touch "${COOLDOWN_DIR}/${1}"
}

# ── Telegram sender ─────────────────────────────────────
send_alert() {
    local message="$1"
    local key="$2"

    if in_cooldown "$key"; then
        return
    fi

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d parse_mode="Markdown" \
        -d text="$message" > /dev/null 2>&1

    set_cooldown "$key"
}

# ── Hostname ────────────────────────────────────────────
HOST=$(hostname)
ALERTS=""

# ── Check 1: Disk usage ────────────────────────────────
DISK_PCT=$(df / | awk 'NR==2{gsub("%",""); print $5}')
if [ "$DISK_PCT" -ge "$DISK_THRESHOLD" ]; then
    ALERTS="${ALERTS}🔴 *Disk* at ${DISK_PCT}% (threshold: ${DISK_THRESHOLD}%)\n"
fi

# ── Check 2: Memory usage ──────────────────────────────
MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEM_USED=$(free -m  | awk 'NR==2{print $3}')
MEM_PCT=$(( MEM_USED * 100 / MEM_TOTAL ))
if [ "$MEM_PCT" -ge "$MEM_THRESHOLD" ]; then
    ALERTS="${ALERTS}🔴 *Memory* at ${MEM_PCT}% (${MEM_USED}/${MEM_TOTAL} MB)\n"
fi

# ── Check 3: Load average ──────────────────────────────
LOAD_1M=$(awk '{print $1}' /proc/loadavg)
LOAD_HIGH=$(awk "BEGIN {print ($LOAD_1M >= $LOAD_THRESHOLD) ? 1 : 0}")
if [ "$LOAD_HIGH" -eq 1 ]; then
    ALERTS="${ALERTS}🔴 *Load* at ${LOAD_1M} (threshold: ${LOAD_THRESHOLD})\n"
fi

# ── Check 4: Docker containers down ────────────────────
if command -v docker &>/dev/null; then
    EXPECTED_CONTAINERS="${WATCHDOG_CONTAINERS:-}"
    if [ -z "$EXPECTED_CONTAINERS" ]; then
        echo "[i] WATCHDOG_CONTAINERS not set — skipping container check"
    else
        for container in $EXPECTED_CONTAINERS; do
            if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                ALERTS="${ALERTS}🔴 *Container down:* \`${container}\`\n"
            fi
        done
    fi

    RESTARTING=$(docker ps --filter "status=restarting" --format '{{.Names}}' 2>/dev/null)
    if [ -n "$RESTARTING" ]; then
        for c in $RESTARTING; do
            ALERTS="${ALERTS}🟡 *Restarting:* \`${c}\`\n"
        done
    fi
fi

# ── Check 5: Nginx health ──────────────────────────────
if docker ps --format '{{.Names}}' | grep -q "oedon-proxy"; then
    if ! docker exec oedon-proxy nginx -t &>/dev/null; then
        ALERTS="${ALERTS}🔴 *Nginx config invalid*\n"
    fi
fi

# ── Check 6: Failed SSH attempts (last 5 min) ──────────
FAILED_SSH=0
for log in /var/log/auth.log /var/log/secure; do
    if [ -f "$log" ]; then
        FAILED_SSH=$(find "$log" -mmin -5 -exec grep -c "Failed password" {} \; 2>/dev/null || echo 0)
        break
    fi
done
if [ "$FAILED_SSH" -gt 10 ]; then
    ALERTS="${ALERTS}🟡 *SSH:* ${FAILED_SSH} failed attempts in last 5 min\n"
fi

# ── Send alert if any ──────────────────────────────────
if [ -n "$ALERTS" ]; then
    MESSAGE="⚠️ *OEDON WATCHDOG* — \`${HOST}\`

${ALERTS}
_$(date '+%Y-%m-%d %H:%M:%S')_"

    ALERT_KEY=$(echo "$ALERTS" | md5sum | cut -d' ' -f1)
    send_alert "$MESSAGE" "$ALERT_KEY"
    echo "[!] Alert sent to Telegram"
else
    echo "[✓] All checks passed — $(date '+%H:%M:%S')"
fi
