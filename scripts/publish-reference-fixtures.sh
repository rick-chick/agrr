#!/usr/bin/env bash
# Maintainer: upload db/fixtures/*_reference_weather.json to GCS and refresh lock file.
#
# Usage:
#   scripts/publish-reference-fixtures.sh [version]
#     version defaults to YYYY.MM.DD (UTC date).
#
# Requires: gcloud, jq, sha256sum. Local fixture files must exist under db/fixtures/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="${AGRR_FIXTURES_LOCK:-$ROOT/config/reference-fixtures.lock.json}"
BUCKET="${AGRR_FIXTURES_BUCKET:-agrr-reference-fixtures}"
PREFIX_BASE="${AGRR_FIXTURES_PREFIX_BASE:-v1}"

version="${1:-$(date -u +%Y.%m.%d)}"
prefix="${PREFIX_BASE}/${version}"

for cmd in jq sha256sum gcloud; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "publish-reference-fixtures: ERROR: $cmd is required" >&2
    exit 1
  }
done

declare -a objects=(
  reference_weather.json
  us_reference_weather.json
  india_reference_weather.json
)

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

files_json="["
first=1
for object in "${objects[@]}"; do
  rel="db/fixtures/${object}"
  path="${ROOT}/${rel}"
  [[ -f "$path" ]] || {
    echo "publish-reference-fixtures: ERROR: missing ${rel}" >&2
    exit 1
  }
  hash="$(sha256_file "$path")"
  size="$(wc -c <"$path" | tr -d ' ')"
  uri="gs://${BUCKET}/${prefix}/${object}"
  echo "publish-reference-fixtures: upload ${uri} (${size} bytes, sha256=${hash})"
  gcloud storage cp "$path" "$uri"

  if [[ "$first" -eq 1 ]]; then
    first=0
  else
    files_json+=","
  fi
  files_json+=$(
    jq -nc \
      --arg path "$rel" \
      --arg object "$object" \
      --arg sha256 "$hash" \
      --argjson size_bytes "$size" \
      '{path: $path, object: $object, sha256: $sha256, size_bytes: $size_bytes}'
  )
done
files_json+="]"

tmp_lock="$(mktemp)"
trap 'rm -f "$tmp_lock"' EXIT
jq -nc \
  --arg version "$version" \
  --arg bucket "$BUCKET" \
  --arg prefix "$prefix" \
  --argjson files "$files_json" \
  '{version: $version, bucket: $bucket, prefix: $prefix, files: $files}' >"$tmp_lock"

mv "$tmp_lock" "$LOCK_FILE"
echo "publish-reference-fixtures: updated ${LOCK_FILE}"
echo "publish-reference-fixtures: commit lock and open PR; old GCS prefixes may be kept 90 days per runbook"
