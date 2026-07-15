#!/usr/bin/env bash
# Ensure db/fixtures/*_reference_weather.json exist per config/reference-fixtures.lock.json.
# Downloads from GCS (or AGRR_FIXTURES_SOURCE_DIR) when missing or sha256 mismatch.
#
# Environment:
#   AGRR_FIXTURES_SKIP=1          — explicit offline skip (exit 0)
#   AGRR_FIXTURES_REQUIRED=1      — exit 1 if any fixture missing/invalid after ensure
#   AGRR_FIXTURES_LOCK            — lock file path (default: config/reference-fixtures.lock.json)
#   AGRR_FIXTURES_CACHE           — cache dir (default: ~/.cache/agrr/fixtures)
#   AGRR_FIXTURES_SOURCE_DIR      — local mirror of gs://bucket/prefix/ for tests/offline
#   AGRR_FIXTURES_GCLOUD=auto      — auto|always|never for gcloud storage cp
set -euo pipefail

ROOT="${AGRR_FIXTURES_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCK_FILE="${AGRR_FIXTURES_LOCK:-$ROOT/config/reference-fixtures.lock.json}"
CACHE_DIR="${AGRR_FIXTURES_CACHE:-${HOME}/.cache/agrr/fixtures}"
GCLOUD_MODE="${AGRR_FIXTURES_GCLOUD:-auto}"

if [[ "${AGRR_FIXTURES_SKIP:-}" == "1" ]]; then
  echo "ensure-reference-fixtures: skip (AGRR_FIXTURES_SKIP=1)"
  exit 0
fi

if [[ ! -f "$LOCK_FILE" ]]; then
  echo "ensure-reference-fixtures: ERROR: lock file not found: $LOCK_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ensure-reference-fixtures: ERROR: jq is required" >&2
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "ensure-reference-fixtures: ERROR: sha256sum is required" >&2
  exit 1
fi

bucket="$(jq -r '.bucket' "$LOCK_FILE")"
prefix="$(jq -r '.prefix' "$LOCK_FILE")"
version="$(jq -r '.version' "$LOCK_FILE")"
mapfile -t entries < <(jq -c '.files[]' "$LOCK_FILE")

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

verify_fixture() {
  local file=$1 expected=$2 expected_size=$3
  [[ -f "$file" ]] || return 1
  local actual_size actual_hash
  actual_size="$(wc -c <"$file" | tr -d ' ')"
  [[ "$actual_size" == "$expected_size" ]] || return 1
  actual_hash="$(sha256_file "$file")"
  [[ "$actual_hash" == "$expected" ]]
}

install_fixture() {
  local src=$1 dest=$2
  local tmp="${dest}.$$.$RANDOM.tmp"
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$tmp"
  mv -f "$tmp" "$dest"
}

cache_path_for() {
  local hash=$1
  echo "${CACHE_DIR}/${hash}"
}

fetch_from_source_dir() {
  local object=$1 dest=$2
  local src="${AGRR_FIXTURES_SOURCE_DIR%/}/${prefix}/${object}"
  [[ -f "$src" ]] || return 1
  cp -f "$src" "$dest"
}

fetch_from_gcloud() {
  local object=$1 dest=$2
  local uri="gs://${bucket}/${prefix}/${object}"
  if [[ "$GCLOUD_MODE" == "never" ]]; then
    return 1
  fi
  if ! command -v gcloud >/dev/null 2>&1; then
    [[ "$GCLOUD_MODE" == "always" ]] && return 1
    return 1
  fi
  mkdir -p "$(dirname "$dest")"
  gcloud storage cp "$uri" "$dest" >/dev/null
}

ensure_one() {
  local entry=$1
  local rel object expected expected_size dest cache
  rel="$(jq -r '.path' <<<"$entry")"
  object="$(jq -r '.object' <<<"$entry")"
  expected="$(jq -r '.sha256' <<<"$entry")"
  expected_size="$(jq -r '.size_bytes' <<<"$entry")"
  dest="${ROOT}/${rel}"
  cache="$(cache_path_for "$expected")"

  if verify_fixture "$dest" "$expected" "$expected_size"; then
    echo "ensure-reference-fixtures: ok ${rel}"
    return 0
  fi

  if [[ -f "$dest" ]]; then
    echo "ensure-reference-fixtures: refresh ${rel} (missing or hash/size mismatch)"
  else
    echo "ensure-reference-fixtures: fetch ${rel}"
  fi

  local tmp
  tmp="$(mktemp)"
  cleanup_tmp() { rm -f "$tmp"; }
  trap cleanup_tmp RETURN

  if [[ -f "$cache" ]] && verify_fixture "$cache" "$expected" "$expected_size"; then
    install_fixture "$cache" "$dest"
    echo "ensure-reference-fixtures: restored ${rel} from cache"
    return 0
  fi

  if [[ -n "${AGRR_FIXTURES_SOURCE_DIR:-}" ]] && fetch_from_source_dir "$object" "$tmp"; then
    :
  elif fetch_from_gcloud "$object" "$tmp"; then
    :
  else
    echo "ensure-reference-fixtures: ERROR: could not fetch ${object} (set AGRR_FIXTURES_SOURCE_DIR or gcloud auth)" >&2
    rm -f "$tmp"
    return 1
  fi

  if ! verify_fixture "$tmp" "$expected" "$expected_size"; then
    echo "ensure-reference-fixtures: ERROR: sha256/size mismatch for ${object}" >&2
    rm -f "$tmp"
    return 1
  fi

  mkdir -p "$CACHE_DIR"
  cp -f "$tmp" "$cache"
  install_fixture "$tmp" "$dest"
  echo "ensure-reference-fixtures: installed ${rel}"
}

missing=0
echo "ensure-reference-fixtures: lock version ${version} (${#entries[@]} weather fixtures)"
for entry in "${entries[@]}"; do
  if ! ensure_one "$entry"; then
    missing=$((missing + 1))
  fi
done

if [[ "${AGRR_FIXTURES_REQUIRED:-}" == "1" ]] && [[ "$missing" -gt 0 ]]; then
  echo "ensure-reference-fixtures: ERROR: ${missing} fixture(s) missing (AGRR_FIXTURES_REQUIRED=1)" >&2
  exit 1
fi

if [[ "$missing" -gt 0 ]]; then
  exit 1
fi

exit 0
