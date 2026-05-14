#!/bin/bash
# update-docker.sh - Automate Docker Compose updates for NPM and Immich
# Recommended: Run weekly via systemd timer or cron

set -e

# Logging
LOG_FILE="/var/log/docker-update.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "--- Update started at $(date) ---"

# 1. Update Nginx Proxy Manager
echo "Updating Nginx Proxy Manager..."
cd ~/Music/npm
docker compose pull
docker compose up -d

# 2. Update Immich
echo "Updating Immich..."
cd /mnt/backup/immich-app
docker compose pull
docker compose up -d

# 3. Cleanup
echo "Pruning old images..."
docker image prune -f

echo "--- Update finished at $(date) ---"
echo ""
