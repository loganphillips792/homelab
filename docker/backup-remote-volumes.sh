#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="logan@10.0.0.33"
REMOTE_BACKUP_DIR="/opt/docker-backups"

# 1) Stop containers, back up volumes, then start containers again on the remote host
ssh "$REMOTE_HOST" bash -s <<'EOF'
set -euo pipefail

HOMELAB_DIR="/home/logan/homelab"
BACKUP_DIR="/home/logan/docker-backups"

echo "Changing to $HOMELAB_DIR..."
cd "$HOMELAB_DIR"

echo "Stopping docker-compose stacks..."
docker compose -f docker/docker-compose.yml down
docker compose --env-file docker/immich/docker-compose.env -f docker/immich/docker-compose.yml down
docker compose --env-file docker/.env -f docker/tubearchivist/docker-compose.yml down

echo "Ensuring backup directory exists at $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

echo "Backing up Docker volumes..."
for v in $(docker volume ls -q); do
  echo "Backing up volume: $v"
  docker run --rm \
    -v "${v}":/volume \
    -v "$BACKUP_DIR":/backup \
    busybox \
    sh -c "cd /volume && tar czf /backup/${v}.tar.gz ."
done

echo "Done. Backups in $BACKUP_DIR"

TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | awk '{print $1}')
echo "Total size of backups in $BACKUP_DIR: $TOTAL_SIZE"

echo "Starting docker-compose stacks..."
docker compose -f docker/docker-compose.yml up -d
docker compose --env-file docker/immich/docker-compose.env -f docker/immich/docker-compose.yml up -d
docker compose --env-file docker/.env -f docker/tubearchivist/docker-compose.yml up -d

echo "All stacks started again."
EOF

# 2) Create a compressed archive of the remote backup dir and save it locally
ARCHIVE_NAME="docker-backups-$(date +%Y%m%d-%H%M%S).tar.gz"

echo "Creating local archive $ARCHIVE_NAME from $REMOTE_HOST:$REMOTE_BACKUP_DIR ..."
ssh "$REMOTE_HOST" "tar czf - -C \"$REMOTE_BACKUP_DIR\" ." > "$ARCHIVE_NAME"

echo "Archive saved locally as: $ARCHIVE_NAME"
LOCAL_SIZE=$(du -sh "$ARCHIVE_NAME" | awk '{print $1}')
echo "Local archive size: $LOCAL_SIZE"