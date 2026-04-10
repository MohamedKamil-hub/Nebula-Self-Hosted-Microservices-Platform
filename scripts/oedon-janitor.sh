#!/bin/bash
# OEDON Janitor - Automated Background Maintenance
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Clear Docker Build Cache (Safe: only removes temporary build files)
docker builder prune -f --filter "until=24h"

# 2. Remove Dangling Images (Safe: only removes images with no name/tag)
docker image prune -f

# 3. Vacuum System Logs (Keep only 2 days of OS logs)
sudo journalctl --vacuum-time=2d

# 4. Optional: Notify via Telegram if disk is still > 90%
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    # Insert your telegram alert script here
    echo "[CRITICAL] Disk usage is at ${DISK_USAGE}%"
fi
