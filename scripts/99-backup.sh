#!/bin/bash
# scripts/99-backup.sh — Oedon Smart Backup System (Robust)
set -euo pipefail

# --- Environment & Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/data/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")

# Load environment if exists (don't fail if missing)
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

mkdir -p "$BACKUP_DIR"

echo "=== Oedon Backup Engine Starting ==="

# ------------------------------------------------------------------
# 1. DATABASE BACKUP (only if container running and vars set)
# ------------------------------------------------------------------
DB_CONTAINER="wordpress-db"
DB_DUMP_SUCCESS=false

if docker ps -q --filter "name=${DB_CONTAINER}" | grep -q .; then
    if [[ -n "${MYSQL_DATABASE:-}" && -n "${MYSQL_USER:-}" && -n "${MYSQL_PASSWORD:-}" ]]; then
        DB_FILE="${BACKUP_DIR}/db_full_${TIMESTAMP}.sql.gz"
        echo "[*] Dumping Database: ${MYSQL_DATABASE}..."
        if docker exec "$DB_CONTAINER" mysqldump -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" 2>/dev/null | gzip > "$DB_FILE"; then
            echo "[OK] Database dump saved: $(basename "$DB_FILE")"
            DB_DUMP_SUCCESS=true
        else
            echo "[WARN] Database dump failed (credentials or database issue)."
        fi
    else
        echo "[WARN] Missing MYSQL_DATABASE, MYSQL_USER, or MYSQL_PASSWORD in .env — skipping DB dump."
    fi
else
    echo "[WARN] Database container '${DB_CONTAINER}' not running — skipping DB dump."
fi

# ------------------------------------------------------------------
# 2. INFRASTRUCTURE BACKUP (configs, apps, .env)
# ------------------------------------------------------------------
INFRA_FILE="${BACKUP_DIR}/infra_full_${TIMESTAMP}.tar.gz"
echo "[*] Compressing Infrastructure & Configs..."
tar -czf "$INFRA_FILE" \
    --exclude="data/backups" \
    --exclude="logs" \
    --exclude=".git" \
    -C "$PROJECT_DIR" \
    data apps config apps.list .env 2>/dev/null || true
echo "[OK] Infrastructure archive created: $(basename "$INFRA_FILE")"

# ------------------------------------------------------------------
# 3. TELEGRAM NOTIFICATION (only if credentials exist)
# ------------------------------------------------------------------
if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "[*] Notifying Telegram..."
    INFRA_SIZE_HUMAN=$(du -h "$INFRA_FILE" 2>/dev/null | cut -f1)
    REPORT_MSG="📦 <b>Oedon Backup Report</b>
📅 Date: <code>${TIMESTAMP}</code>
📂 Infra (Local): <code>${INFRA_SIZE_HUMAN:-unknown}</code>"

    if $DB_DUMP_SUCCESS && [ -f "$DB_FILE" ]; then
        DB_SIZE=$(stat -c%s "$DB_FILE" 2>/dev/null || echo 0)
        DB_SIZE_HUMAN=$(du -h "$DB_FILE" 2>/dev/null | cut -f1)
        REPORT_MSG="${REPORT_MSG}
💾 Database: <code>${DB_SIZE_HUMAN:-unknown}</code>"
        MAX_SIZE=$((50 * 1024 * 1024))  # 50 MB
        if [ "$DB_SIZE" -le "$MAX_SIZE" ] && [ "$DB_SIZE" -gt 0 ]; then
            echo "[*] Sending Database to Telegram..."
            curl -s -F chat_id="${TELEGRAM_CHAT_ID}" \
                 -F document=@"$DB_FILE" \
                 "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendDocument" > /dev/null || echo "[WARN] Failed to send DB file."
        else
            REPORT_MSG="${REPORT_MSG}
⚠️ DB file too large or empty. Stored locally only."
        fi
    else
        REPORT_MSG="${REPORT_MSG}
⚠️ No database dump available."
    fi

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$REPORT_MSG" \
        -d parse_mode="HTML" > /dev/null || true
else
    echo "[INFO] Telegram credentials not set — skipping notification."
fi

# ------------------------------------------------------------------
# 4. ROTATION (keep last 7 days)
# ------------------------------------------------------------------
echo "[*] Cleaning up backups older than 7 days..."
find "$BACKUP_DIR" -type f \( -name "*.gz" -o -name "*.tar.gz" \) -mtime +7 -delete 2>/dev/null || true

echo "=== Backup Process Completed ==="
