#!/usr/bin/env bash
set -euo pipefail

# USAGE CHECK
if [ -z "${1:-}" ]; then
    echo "Usage: $0 <path_to_local_archive.tar.gz>"
    exit 1
fi

LOCAL_ARCHIVE="$1"
REMOTE_HOST="logan@10.0.0.33"
REMOTE_TEMP_DIR="/tmp/docker-restore-$(date +%s)"

echo "=== STARTING RESTORE PROCESS ==="
echo "Target: $REMOTE_HOST"
echo "Source: $LOCAL_ARCHIVE"
echo ""

# 1) Transfer the archive to the remote host
echo "1. Uploading archive to remote host..."
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_TEMP_DIR"
scp "$LOCAL_ARCHIVE" "$REMOTE_HOST:$REMOTE_TEMP_DIR/full_backup.tar.gz"

# 2) Perform the restore operations remotely
echo "2. Connecting to remote host to perform restore..."
ssh "$REMOTE_HOST" bash -s <<EOF
set -euo pipefail

HOMELAB_DIR="/home/logan/homelab"
RESTORE_DIR="$REMOTE_TEMP_DIR/extracted"

# Extract the main archive to get individual volume tarballs
echo "   Extracting main archive on remote..."
mkdir -p "\$RESTORE_DIR"
tar xzf "$REMOTE_TEMP_DIR/full_backup.tar.gz" -C "\$RESTORE_DIR"

# Stop containers (Must match your backup script logic to release locks)
echo "   Stopping docker-compose stacks..."
cd "\$HOMELAB_DIR"
docker compose -f docker/docker-compose.yml down
docker compose --env-file docker/immich/docker-compose.env -f docker/immich/docker-compose.yml down
docker compose --env-file docker/.env -f docker/tubearchivist/docker-compose.yml down

echo "   Restoring volumes..."
# Loop through every tar.gz file found in the extracted directory
for f in "\$RESTORE_DIR"/*.tar.gz; do
    # Get volume name from filename (e.g., "my_vol.tar.gz" -> "my_vol")
    vol_name=\$(basename "\$f" .tar.gz)
    
    echo "   -> Restoring volume: \$vol_name"
    
    # Check if volume exists, create if not (though docker run usually handles this)
    docker volume create "\$vol_name" > /dev/null

    # Run busybox to wipe current volume data and inject backup data
    # We mount the specific backup file to /backup/source.tar.gz inside the container
    docker run --rm \\
        -v "\$vol_name":/volume \\
        -v "\$f":/backup/source.tar.gz \\
        busybox \\
        sh -c "cd /volume && rm -rf ..?* .[!.]* * && tar xzf /backup/source.tar.gz"
done

echo "   Cleaning up temp files..."
rm -rf "$REMOTE_TEMP_DIR"

echo "   Starting docker-compose stacks..."
docker compose -f docker/docker-compose.yml up -d
docker compose --env-file docker/immich/docker-compose.env -f docker/immich/docker-compose.yml up -d
docker compose --env-file docker/.env -f docker/tubearchivist/docker-compose.yml up -d

echo "=== RESTORE COMPLETE ==="
EOF