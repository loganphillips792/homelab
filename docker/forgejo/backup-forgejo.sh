#!/bin/bash
set -euo pipefail

export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
export RESTIC_REPOSITORY=$HOME/restic/homelab
export RESTIC_PASSWORD_FILE=$HOME/.restic-password

trap 'docker start forgejo' EXIT

docker stop forgejo
restic backup "$HOME/docker-volumes/forgejo" --tag forgejo
docker start forgejo
trap - EXIT

restic forget --tag forgejo --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
