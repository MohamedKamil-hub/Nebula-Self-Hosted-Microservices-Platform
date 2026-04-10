#!/bin/bash
# scripts/99-backup.sh — Oedon Smart Backup System
# Author: m-kamil-oedon
set -euo pipefail

# --- Environment & Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/data/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")

# Load environment variables
if [ -f "${PROJECT_DIR}/.env" ]; then
    source "${PROJECT_DIR}/.env"
else
    echo "[!] Error: .env file not found."
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# File naming
DB_FILE="${BACKUP_DIR}/db_full_${TIMESTAMP}.sql.gz"
INFRA_FILE="${BACKUP_DIR}/infra_full_${TIMESTAMP}.tar.gz"

echo "=== Oedon Backup Engine Starting ==="

# 1. DATABASE BACKUP (Full Compressed Dump)
echo "[*] Dumping Database: ${MYSQL_DATABASE}..."
docker exec wordpress-db mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" > "${BACKUP_DIR}/db_backup.sql"
# 2. INFRASTRUCTURE BACKUP (Local Only)
# Includes config, apps, app.list and secrets. Excludes logs and existing backups.
echo "[*] Compressing Infrastructure & Configs..."
tar -czf "$INFRA_FILE" \
    --exclude="data/backups" \
    --exclude="logs" \
    --exclude=".git" \
    -C "$PROJECT_DIR" \
    data apps config apps.list .env 2>/dev/null || true

# 3. TELEGRAM INTEGRATION
echo "[*] Notifying Telegram..."

DB_SIZE=$(stat -c%s "$DB_FILE")
MAX_SIZE=$((50 * 1024 * 1024)) # 50MB Limit
DB_SIZE_HUMAN=$(du -h "$DB_FILE" | cut -f1)
INFRA_SIZE_HUMAN=$(du -h "$INFRA_FILE" | cut -f1)

# Send Status Report
REPORT_MSG="📦 <b>Oedon Backup Report</b>
📅 Date: <code>${TIMESTAMP}</code>
📂 Infra (Local): <code>${INFRA_SIZE_HUMAN}</code>
💾 Database: <code>${DB_SIZE_HUMAN}</code>"

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="$REPORT_MSG" \
    -d parse_mode="HTML" > /dev/null

# Send DB File if under 50MB
if [ "$DB_SIZE" -le "$MAX_SIZE" ]; then
    echo "[*] Sending Database to Telegram..."
    curl -s -F chat_id="${TELEGRAM_CHAT_ID}" \
         -F document=@"$DB_FILE" \
         "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" > /dev/null
else
    echo "[!] DB too large for Telegram API. Saved locally."
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="⚠️ DB size exceeds 50MB. File stored in local server only." > /dev/null
fi

# 4. ROTATION (Keep last 7 days)
echo "[*] Cleaning up old backups..."
find "$BACKUP_DIR" -type f -name "*.gz" -mtime +7 -delete

echo "=== Backup Process Completed Successfully ==="
