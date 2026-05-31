#!/usr/bin/env bash
# Restore production primary SQLite from GCS Litestream replica into tmp/ (gitignored).
# Use for agrr-migrate dry-run / data apply verification before touching live Cloud Run.
#
#   ./scripts/refresh-production-primary-replica.sh
#
# Output:
#   tmp/production-primary-replica/primary.sqlite3
#   tmp/production-primary-replica/manifest.txt
#
# Env: GCS_BUCKET, LITESTREAM_REPLICA (same as production-primary-sqlite-query skill)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="${ROOT}/tmp/production-primary-replica"
QUERY_SCRIPT="${ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh"

GCS_BUCKET="${GCS_BUCKET:-agrr-production-db}"
LITESTREAM_REPLICA="${LITESTREAM_REPLICA:-production/primary.sqlite3}"

if [ ! -x "$QUERY_SCRIPT" ] && [ -f "$QUERY_SCRIPT" ]; then
  chmod +x "$QUERY_SCRIPT"
fi

mkdir -p "$DEST_DIR"

echo "==> Restoring gs://${GCS_BUCKET}/${LITESTREAM_REPLICA}"
TMP_DB="$(KEEP_DB=1 GCS_BUCKET="$GCS_BUCKET" LITESTREAM_REPLICA="$LITESTREAM_REPLICA" "$QUERY_SCRIPT")"

if [ ! -f "$TMP_DB" ]; then
  echo "ERROR: restore failed (no file at $TMP_DB)" >&2
  exit 1
fi

OUT_DB="${DEST_DIR}/primary.sqlite3"
cp -f "$TMP_DB" "${OUT_DB}.new"
mv -f "${OUT_DB}.new" "$OUT_DB"

RESTORED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
BYTES="$(wc -c <"$OUT_DB" | tr -d ' ')"

cat >"${DEST_DIR}/manifest.txt" <<EOF
restored_at_utc=${RESTORED_AT}
gcs_bucket=${GCS_BUCKET}
litestream_replica=${LITESTREAM_REPLICA}
bytes=${BYTES}
path=${OUT_DB}
note=Read-only copy from Litestream; may lag live primary by sync-interval (30s). Not for Litestream replicate back to production without ops runbook.
EOF

# Ephemeral temp from query script (parent mktemp dir)
rm -f "$TMP_DB"
TMP_PARENT="$(dirname "$TMP_DB")"
if [ -d "$TMP_PARENT" ] && [ "$TMP_PARENT" != "$DEST_DIR" ]; then
  rm -rf "$TMP_PARENT"
fi

echo "==> Wrote ${OUT_DB} (${BYTES} bytes)"
echo "==> Manifest: ${DEST_DIR}/manifest.txt"
echo ""
echo "Example (agrr-migrate dry-run on copy):"
echo "  export AGRR_APP_ROOT=${ROOT}"
echo "  export AGRR_SQLITE_PATH=${OUT_DB}"
echo "  agrr-migrate schema verify"
echo "  agrr-migrate data list"
