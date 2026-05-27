#!/bin/bash
# Restore production primary SQLite from GCS (Litestream replica) and run sqlite3.
# Requires: curl, sqlite3, gcloud ADC (e.g. gcloud auth application-default login).
#
# Litestream version must match Dockerfile.production (currently 0.3.13) — replica type "gcs".
#
# Usage (from repository root):
#   ./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh
#   ./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh "SELECT COUNT(*) FROM users WHERE is_anonymous = 0;"
#
# Env:
#   GCS_BUCKET          default: agrr-production-db
#   LITESTREAM_REPLICA  default: production/primary.sqlite3
#   LITESTREAM_BIN      path to litestream binary (optional)
#   KEEP_DB             if set, print path to restored DB and skip deletion

set -euo pipefail

GCS_BUCKET="${GCS_BUCKET:-agrr-production-db}"
LITESTREAM_REPLICA="${LITESTREAM_REPLICA:-production/primary.sqlite3}"
LITESTREAM_VERSION="${LITESTREAM_VERSION:-0.3.13}"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/agrr-litestream"
DEB_URL="https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-amd64.deb"
LITESTREAM_CACHED="${CACHE_ROOT}/v${LITESTREAM_VERSION}/litestream"

SQL_DEFAULT=$'SELECT \'all_rows\' AS label, COUNT(*) AS n FROM users\nUNION ALL SELECT \'registered (is_anonymous=0)\', COUNT(*) FROM users WHERE is_anonymous = 0\nUNION ALL SELECT \'anonymous (is_anonymous=1)\', COUNT(*) FROM users WHERE is_anonymous = 1;'

ensure_litestream() {
  if [[ -n "${LITESTREAM_BIN:-}" && -x "${LITESTREAM_BIN}" ]]; then
    return 0
  fi
  if [[ -x "$LITESTREAM_CACHED" ]]; then
    LITESTREAM_BIN="$LITESTREAM_CACHED"
    return 0
  fi
  mkdir -p "$(dirname "$LITESTREAM_CACHED")"
  local deb
  deb="$(mktemp)"
  curl -fsSL -o "$deb" "$DEB_URL"
  dpkg-deb -x "$deb" "$(dirname "$LITESTREAM_CACHED")/extract"
  mv "$(dirname "$LITESTREAM_CACHED")/extract/usr/bin/litestream" "$LITESTREAM_CACHED"
  rm -rf "$(dirname "$LITESTREAM_CACHED")/extract" "$deb"
  chmod +x "$LITESTREAM_CACHED"
  LITESTREAM_BIN="$LITESTREAM_CACHED"
}

command -v sqlite3 >/dev/null || { echo "sqlite3 is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo "dpkg-deb is required (install dpkg or use Debian/Ubuntu)" >&2; exit 1; }

ensure_litestream

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
if [[ -z "${KEEP_DB:-}" ]]; then
  trap cleanup EXIT
fi

CONFIG="$TMP_DIR/litestream.yml"
FAKE_DB="$TMP_DIR/primary.sqlite3"
OUT_DB="$TMP_DIR/restored.sqlite3"

cat > "$CONFIG" <<EOF
dbs:
  - path: ${FAKE_DB}
    replicas:
      - type: gcs
        bucket: ${GCS_BUCKET}
        path: ${LITESTREAM_REPLICA}
EOF

echo "Restoring gs://${GCS_BUCKET}/${LITESTREAM_REPLICA} (Litestream v${LITESTREAM_VERSION})..." >&2
# Litestream logs to stdout; redirect so KEEP_DB=$(...) captures only the DB path.
"$LITESTREAM_BIN" restore -config "$CONFIG" -o "$OUT_DB" "$FAKE_DB" >&2

if [[ -n "${KEEP_DB:-}" ]]; then
  echo "$OUT_DB" >&1
  trap - EXIT
  exit 0
fi

SQL="${1:-}"
if [[ -z "$SQL" ]]; then
  sqlite3 -header -column "$OUT_DB" "$SQL_DEFAULT"
else
  sqlite3 -header -column "$OUT_DB" "$SQL"
fi
