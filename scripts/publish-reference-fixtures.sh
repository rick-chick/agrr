#!/usr/bin/env bash
# Maintainer: upload reference weather fixtures to GCS and refresh lock file.
# Requires: gcloud or gsutil, local db/fixtures/*_reference_weather.json with real content.
#
# Usage:
#   scripts/publish-reference-fixtures.sh [--version YYYY.MM.DD] [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="$ROOT/config/reference-fixtures.lock.json"
BUCKET="${AGRR_REFERENCE_FIXTURES_BUCKET:-agrr-reference-fixtures}"
VERSION=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h | --help)
      echo "Usage: $0 [--version YYYY.MM.DD] [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$VERSION" ]; then
  VERSION="$(date +%Y.%m.%d)"
fi

PREFIX="v1/${VERSION}"

WEATHER_FILES=(
  db/fixtures/reference_weather.json
  db/fixtures/us_reference_weather.json
  db/fixtures/india_reference_weather.json
)

echo "==> publish-reference-fixtures version=$VERSION bucket=$BUCKET prefix=$PREFIX"

ENTRIES_JSON="[]"
for rel in "${WEATHER_FILES[@]}"; do
  local_path="$ROOT/$rel"
  if [ ! -f "$local_path" ]; then
    echo "ERROR: missing local file: $local_path" >&2
    exit 1
  fi
  if head -1 "$local_path" | grep -q 'git-lfs.github.com'; then
    echo "ERROR: $rel is still an LFS pointer — run git lfs pull or obtain real JSON first" >&2
    exit 1
  fi
  object="$(basename "$rel")"
  sha="$(sha256sum "$local_path" | awk '{print $1}')"
  size="$(wc -c <"$local_path" | tr -d ' ')"
  gcs_uri="gs://${BUCKET}/${PREFIX}/${object}"
  echo "  $rel → $gcs_uri (sha256=$sha, size=$size)"
  if [ "$DRY_RUN" -eq 0 ]; then
    if command -v gcloud >/dev/null 2>&1; then
      gcloud storage cp "$local_path" "$gcs_uri" --quiet
    elif command -v gsutil >/dev/null 2>&1; then
      gsutil -q cp "$local_path" "$gcs_uri"
    else
      echo "ERROR: gcloud or gsutil required" >&2
      exit 1
    fi
  fi
  ENTRIES_JSON="$(echo "$ENTRIES_JSON" | jq -c \
    --arg path "$rel" --arg object "$object" --arg sha "$sha" --argjson size "$size" \
    '. + [{path: $path, object: $object, sha256: $sha, size_bytes: $size}]')"
done

LOCK_JSON="$(jq -n \
  --arg version "$VERSION" \
  --arg bucket "$BUCKET" \
  --arg prefix "$PREFIX" \
  --argjson files "$ENTRIES_JSON" \
  '{version: $version, bucket: $bucket, prefix: $prefix, files: $files}')"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "$LOCK_JSON" | jq .
  echo "==> dry-run: lock not written, GCS not uploaded"
  exit 0
fi

echo "$LOCK_JSON" | jq . >"$LOCK_FILE"
echo "==> Updated $LOCK_FILE"
echo "==> Commit lock file and merge. Old GCS prefix may be retained for 90 days."
