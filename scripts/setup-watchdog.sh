#!/bin/bash
# setup-watchdog.sh - Install watchdog cron job
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHDOG="${SCRIPT_DIR}/oedon-watchdog.sh"

chmod +x "$WATCHDOG"

# Add cron job (every 5 minutes)
CRON_LINE="*/5 * * * * ${WATCHDOG} >> /var/log/oedon-watchdog.log 2>&1"

# Check if already installed
if crontab -l 2>/dev/null | grep -q "oedon-watchdog"; then
    echo "[i] Watchdog cron already installed"
else
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "[✓] Watchdog cron installed (every 5 min)"
fi

# Test Telegram connection
source "$(dirname "$SCRIPT_DIR")/.env"
echo "[*] Testing Telegram connection..."
RESPONSE=$(curl -s -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="Markdown" \
    -d text="✅ *OEDON WATCHDOG* activado en \`$(hostname)\`
_$(date '+%Y-%m-%d %H:%M:%S')_")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "[✓] Telegram test message sent!"
else
    echo "[✗] Telegram failed. Check TELEGRAM_TOKEN and TELEGRAM_CHAT_ID in .env"
    echo "    Response: $RESPONSE"
fi

echo ""
echo "[i] Watchdog checks: disk, memory, load, containers, nginx, SSH"
echo "[i] Alerts cooldown: 30 min (won't spam)"
echo "[i] Log: /var/log/oedon-watchdog.log"
