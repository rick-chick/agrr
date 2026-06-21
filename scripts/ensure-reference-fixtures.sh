#!/usr/bin/env bash
# Ensure db/fixtures/*_reference_weather.json exist locally (GCS download + sha256 verify).
# Lock contract: config/reference-fixtures.lock.json
#
# Env:
#   AGRR_FIXTURES_SKIP=1       — skip (offline)
#   AGRR_FIXTURES_REQUIRED=1   — exit 1 when any fixture missing/mismatch after ensure
#   AGRR_FIXTURES_CACHE_DIR    — download cache (default: ~/.cache/agrr/fixtures)
#   AGRR_MIGRATE_WEATHER_FIXTURE — per-file override (unchanged)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="${AGRR_REFERENCE_FIXTURES_LOCK:-$ROOT/config/reference-fixtures.lock.json}"
CACHE_DIR="${AGRR_FIXTURES_CACHE_DIR:-$HOME/.cache/agrr/fixtures}"

if [ "${AGRR_FIXTURES_SKIP:-}" = "1" ]; then
  echo "==> ensure-reference-fixtures: skipped (AGRR_FIXTURES_SKIP=1)"
  exit 0
fi

if [ ! -f "$LOCK_FILE" ]; then
  echo "ERROR: lock file not found: $LOCK_FILE" >&2
  exit 1
fi

# shellcheck disable=SC2016
PLAN_JSON="$(node --input-type=module -e "
import { readLockFile, planFixtureEnsure } from '${ROOT}/scripts/ensure-reference-fixtures-lib.mjs';
const lock = readLockFile('${LOCK_FILE}');
const plans = planFixtureEnsure(lock, '${ROOT}');
console.log(JSON.stringify({ lock, plans }));
")"

REQUIRED="${AGRR_FIXTURES_REQUIRED:-0}"
FAIL=0

download_one() {
  local gcs_uri="$1"
  local dest="$2"
  local expected_sha="$3"
  local cache_path="$4"

  mkdir -p "$(dirname "$dest")" "$(dirname "$cache_path")"

  if [ -f "$cache_path" ]; then
    local cache_sha
    cache_sha="$(sha256sum "$cache_path" | awk '{print $1}')"
    if [ "$cache_sha" = "$expected_sha" ]; then
      echo "    cache hit: $cache_path"
      cp -f "$cache_path" "$dest"
      return 0
    fi
    rm -f "$cache_path"
  fi

  echo "    downloading: $gcs_uri"
  if command -v gcloud >/dev/null 2>&1; then
    gcloud storage cp "$gcs_uri" "$cache_path" --quiet
  elif command -v gsutil >/dev/null 2>&1; then
    gsutil -q cp "$gcs_uri" "$cache_path"
  else
    echo "ERROR: gcloud or gsutil required to fetch $gcs_uri" >&2
    return 1
  fi

  local got_sha
  got_sha="$(sha256sum "$cache_path" | awk '{print $1}')"
  if [ "$got_sha" != "$expected_sha" ]; then
    echo "ERROR: sha256 mismatch for $gcs_uri (expected $expected_sha, got $got_sha)" >&2
    rm -f "$cache_path"
    return 1
  fi

  cp -f "$cache_path" "$dest"
}

echo "==> ensure-reference-fixtures (lock: $LOCK_FILE)"

while IFS= read -r line; do
  status="$(echo "$line" | jq -r '.status')"
  path="$(echo "$line" | jq -r '.localPath')"
  gcs="$(echo "$line" | jq -r '.gcsUri')"
  sha="$(echo "$line" | jq -r '.sha256')"
  rel="$(echo "$line" | jq -r '.path')"
  object="$(basename "$path")"
  cache_path="$CACHE_DIR/$(echo "$line" | jq -r '.lockVersion')/$object"

  case "$status" in
    ok)
      echo "  OK  $rel"
      ;;
    missing|hash_mismatch)
      echo "  FETCH $rel ($status)"
      if ! download_one "$gcs" "$path" "$sha" "$cache_path"; then
        FAIL=1
      else
        echo "  OK  $rel (fetched)"
      fi
      ;;
    *)
      echo "ERROR: unknown status $status for $rel" >&2
      FAIL=1
      ;;
  esac
done < <(
  echo "$PLAN_JSON" | jq -c --arg lv "$(echo "$PLAN_JSON" | jq -r '.lock.version')" \
    '.plans[] | . + {sha256: .entry.sha256, path: .entry.path, lockVersion: $lv}'
)

if [ "$FAIL" -eq 1 ]; then
  if [ "$REQUIRED" = "1" ]; then
    echo "ERROR: ensure-reference-fixtures failed (AGRR_FIXTURES_REQUIRED=1)" >&2
    exit 1
  fi
  echo "WARN: ensure-reference-fixtures incomplete (set AGRR_FIXTURES_REQUIRED=1 to fail hard)" >&2
  exit 0
fi

# Re-check after downloads
EXIT_CODE="$(node --input-type=module -e "
import { readLockFile, planFixtureEnsure, ensureExitCode } from '${ROOT}/scripts/ensure-reference-fixtures-lib.mjs';
const lock = readLockFile('${LOCK_FILE}');
const plans = planFixtureEnsure(lock, '${ROOT}');
process.exit(ensureExitCode(plans, ${REQUIRED} === 1));
")"
exit "$EXIT_CODE"
