#!/usr/bin/env bash
#
# Off-site backup of the cuaderno vault to a restic repository.
#
# WHY THIS EXISTS
#   The vault lives on two Macs plus a git remote, but the two Macs are one
#   failure domain: they sync within seconds, so anything that propagates — a
#   bad merge, an accidental delete, index corruption — reaches both. The git
#   remote is the only independent copy and it is a third party.
#
#   It is also incomplete. `.cuaderno/config.toml`, `templates/` and
#   `custom.css` are gitignored as machine-local, so the remote does not carry
#   them, yet they are what *interprets* every note (custom note types,
#   tracking contracts, schema overrides). Restore markdown without them and
#   the notes survive while the rules for reading them do not. This backup is
#   the only copy of that ~80 KB.
#
# SECRETS
#   nix-configs is a PUBLIC repository. Nothing secret may appear in this file.
#   Credentials live in a mode-600 env file outside the repo; see ENV_FILE.
set -euo pipefail

ENV_FILE="$HOME/.config/restic/vault-r2.env"
VAULT="$HOME/notebook"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }
fail() { log "FATAL: $*"; exit "$2"; }

[ -f "$ENV_FILE" ] || fail "no env file at $ENV_FILE - backup not configured" 78

# A credentials file the group or world can read is a bug, not a preference.
perms="$(stat -f '%Lp' "$ENV_FILE")"
[ "$perms" = "600" ] || fail "$ENV_FILE is mode $perms, expected 600" 77

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

for var in RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  eval "val=\${$var:-}"
  [ -n "$val" ] || fail "$var is unset in $ENV_FILE" 78
done

[ -d "$VAULT" ] || fail "vault not found at $VAULT" 66

log "=== backup starting: $VAULT ==="

# index.db and its sidecars are a live SQLite database owned by the container:
# rebuildable from the markdown, and unsafe to snapshot mid-write. Everything
# else under .cuaderno/ is deliberately included - it is the irreplaceable part.
restic backup "$VAULT" \
  --tag vault \
  --exclude "$VAULT/.cuaderno/index.db" \
  --exclude "$VAULT/.cuaderno/index.db-wal" \
  --exclude "$VAULT/.cuaderno/index.db-shm" \
  --exclude "$VAULT/.cuaderno/.lock" \
  --exclude ".DS_Store"

log "=== pruning old snapshots ==="

# The vault is ~140 MB, so retention is generous on purpose: storage is far
# cheaper than discovering a deletion three months late.
restic forget \
  --tag vault \
  --keep-daily 14 \
  --keep-weekly 8 \
  --keep-monthly 24 \
  --keep-yearly 10 \
  --prune

# Structural check every run, plus a rotating slice of actual data. Over a
# fortnight this reads the whole repository. A backup nobody verifies is a
# hope, and R2 egress is free, so there is no reason to skip it.
log "=== integrity check ==="
restic check --read-data-subset=10%

log "=== backup complete ==="
restic snapshots --tag vault --latest 1
