#!/usr/bin/env bash
# Cold backup of the ArchiveBox data volume from the homelab server.
#
# Stops the container so SQLite and the archive tree are quiescent, streams a
# gzipped tar of the volume over ssh, restarts the container, then verifies the
# local archive before declaring success.
#
# Usage:  ./backup-archivebox.sh [output-dir]
#         OUT_DIR=~/somewhere-else ./backup-archivebox.sh
#
# Env overrides: REMOTE_HOST, CONTAINER, REMOTE_VOLUME_PARENT, OUT_DIR

set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:-logan@192.168.1.150}"
CONTAINER="${CONTAINER:-archivebox}"
# Parent dir on the remote host; the CONTAINER-named subdir inside it is tarred.
# Left unexpanded locally on purpose so the remote shell resolves the tilde.
REMOTE_VOLUME_PARENT="${REMOTE_VOLUME_PARENT:-~/docker-volumes}"
OUT_DIR="${1:-${OUT_DIR:-$HOME/archivebox-backup}}"

mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${CONTAINER}-$(date +%Y%m%d-%H%M%S).tar.gz"

echo "Backing up $CONTAINER from $REMOTE_HOST"
echo "  -> $OUT"

# The ';' before 'docker start' is deliberate: the container comes back even if
# tar fails. The cost is that ssh's exit status reflects 'docker start', the
# last command in the chain, so it cannot tell us whether tar succeeded --
# hence the verification step below rather than a plain 'set -e' trust fall.
ssh "$REMOTE_HOST" \
  "docker stop $CONTAINER >/dev/null && tar czf - -C $REMOTE_VOLUME_PARENT $CONTAINER; docker start $CONTAINER >/dev/null" \
  > "$OUT"

# Verify: 'tar tzf' catches truncation/corruption -- including a short write
# from a full disk -- but exits 0 on a zero-byte file, which is what a failed
# 'docker stop' leaves behind, since the shell creates the redirect target
# before ssh ever runs. So gate on the entry count too.
if ! ENTRIES=$(tar tzf "$OUT" 2>/dev/null | wc -l | tr -d ' ') || [ "$ENTRIES" -eq 0 ]; then
  echo "FAILED: $OUT is empty or corrupt -- removing" >&2
  rm -f "$OUT"
  exit 1
fi

echo "OK: $(du -h "$OUT" | cut -f1), $ENTRIES entries"
