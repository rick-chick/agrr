#!/usr/bin/env bash
# Contract tests for scripts/ensure-reference-fixtures.sh (no GCS; uses AGRR_FIXTURES_SOURCE_DIR).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENSURE="${ROOT}/scripts/ensure-reference-fixtures.sh"
FAIL=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; FAIL=1; }

need_cmds() {
  for cmd in jq sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || {
      echo "ensure-reference-fixtures-test: ERROR: $cmd required" >&2
      exit 1
    }
  done
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

setup_fixture_tree() {
  local work=$1
  local lock=$2
  local src_root=$3
  mkdir -p "${work}/db/fixtures" "${src_root}/v1/test"

  printf '%s' '{"jp":{"lat":35}}' >"${work}/db/fixtures/reference_weather.json"
  printf '%s' '{"us":{"lat":40}}' >"${work}/db/fixtures/us_reference_weather.json"
  printf '%s' '{"in":{"lat":28}}' >"${work}/db/fixtures/india_reference_weather.json"

  local h1 h2 h3 s1 s2 s3
  h1="$(sha256_file "${work}/db/fixtures/reference_weather.json")"
  h2="$(sha256_file "${work}/db/fixtures/us_reference_weather.json")"
  h3="$(sha256_file "${work}/db/fixtures/india_reference_weather.json")"
  s1="$(wc -c <"${work}/db/fixtures/reference_weather.json" | tr -d ' ')"
  s2="$(wc -c <"${work}/db/fixtures/us_reference_weather.json" | tr -d ' ')"
  s3="$(wc -c <"${work}/db/fixtures/india_reference_weather.json" | tr -d ' ')"

  cp "${work}/db/fixtures/reference_weather.json" "${src_root}/v1/test/reference_weather.json"
  cp "${work}/db/fixtures/us_reference_weather.json" "${src_root}/v1/test/us_reference_weather.json"
  cp "${work}/db/fixtures/india_reference_weather.json" "${src_root}/v1/test/india_reference_weather.json"

  jq -n \
    --arg version "test" \
    --arg bucket "agrr-reference-fixtures" \
    --arg prefix "v1/test" \
    --arg h1 "$h1" --argjson s1 "$s1" \
    --arg h2 "$h2" --argjson s2 "$s2" \
    --arg h3 "$h3" --argjson s3 "$s3" \
    '{
      version: $version,
      bucket: $bucket,
      prefix: $prefix,
      files: [
        {path: "db/fixtures/reference_weather.json", object: "reference_weather.json", sha256: $h1, size_bytes: $s1},
        {path: "db/fixtures/us_reference_weather.json", object: "us_reference_weather.json", sha256: $h2, size_bytes: $s2},
        {path: "db/fixtures/india_reference_weather.json", object: "india_reference_weather.json", sha256: $h3, size_bytes: $s3}
      ]
    }' >"$lock"
}

run_ensure() {
  local work=$1 lock=$2 src=$3
  shift 3
  (
    AGRR_FIXTURES_ROOT="$work" \
      AGRR_FIXTURES_LOCK="$lock" \
      AGRR_FIXTURES_SOURCE_DIR="$src" \
      AGRR_FIXTURES_GCLOUD=never \
      AGRR_FIXTURES_CACHE="${work}/cache" \
      bash "$ENSURE" "$@"
  )
}

need_cmds
[[ -x "$ENSURE" ]] || chmod +x "$ENSURE"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOCK="${WORK}/lock.json"
SRC="${WORK}/gcs-mirror"
setup_fixture_tree "$WORK" "$LOCK" "$SRC"

# Remove local copies; ensure should restore from source dir.
rm -f "${WORK}/db/fixtures/"*.json

if run_ensure "$WORK" "$LOCK" "$SRC"; then
  pass "fetch from AGRR_FIXTURES_SOURCE_DIR"
else
  fail "fetch from AGRR_FIXTURES_SOURCE_DIR"
fi

for f in reference_weather.json us_reference_weather.json india_reference_weather.json; do
  [[ -f "${WORK}/db/fixtures/${f}" ]] || fail "missing after fetch: ${f}"
done

if run_ensure "$WORK" "$LOCK" "$SRC"; then
  pass "idempotent second run"
else
  fail "idempotent second run"
fi

# AGRR_FIXTURES_REQUIRED: unavailable fixture must exit 1
REQ_WORK="$(mktemp -d)"
REQ_LOCK="${REQ_WORK}/lock.json"
REQ_SRC="${REQ_WORK}/gcs-mirror"
setup_fixture_tree "$REQ_WORK" "$REQ_LOCK" "$REQ_SRC"
rm -f "${REQ_WORK}/db/fixtures/reference_weather.json" "${REQ_SRC}/v1/test/reference_weather.json"
if AGRR_FIXTURES_REQUIRED=1 run_ensure "$REQ_WORK" "$REQ_LOCK" "$REQ_SRC" >/dev/null 2>&1; then
  fail "AGRR_FIXTURES_REQUIRED=1 should fail when fixture unavailable"
else
  pass "AGRR_FIXTURES_REQUIRED=1 fails on missing fixture"
fi
rm -rf "$REQ_WORK"

# corrupt hash in lock -> should fail fetch/verify
run_ensure "$WORK" "$LOCK" "$SRC" >/dev/null
rm -f "${WORK}/db/fixtures/"*.json
jq '.files[0].sha256 = "deadbeef"' "$LOCK" >"${LOCK}.bad"
mv "${LOCK}.bad" "$LOCK"
if run_ensure "$WORK" "$LOCK" "$SRC" >/dev/null 2>&1; then
  fail "corrupt lock hash should fail"
else
  pass "corrupt lock hash fails verification"
fi

if AGRR_FIXTURES_SKIP=1 bash "$ENSURE" >/dev/null 2>&1; then
  pass "AGRR_FIXTURES_SKIP=1 exits 0"
else
  fail "AGRR_FIXTURES_SKIP=1"
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "ensure-reference-fixtures-test: FAILED" >&2
  exit 1
fi

echo "ensure-reference-fixtures-test: all passed"
