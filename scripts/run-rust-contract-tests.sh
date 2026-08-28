#!/usr/bin/env bash
# R4 contract tests: co-located agrr-server + agrr-r4-contract (Rust only; P8.6).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BINARY="${ROOT}/tmp/agrr-server-contract/agrr-server"
MIGRATE_BINARY="${ROOT}/tmp/agrr-server-contract/agrr-migrate"
R4_CONTRACT_TESTS_BIN="${ROOT}/tmp/agrr-server-contract/agrr-r4-contract-tests"
mkdir -p "$(dirname "$BINARY")"

# Directory mtime does not advance when files inside are edited; compare leaf sources.
contract_rust_sources_newer_than() {
  local binary="$1"
  shift
  local dir
  for dir in "$@"; do
    if find "$dir" -type f \( -name '*.rs' -o -name 'Cargo.toml' \) -newer "$binary" -print -quit | grep -q .; then
      return 0
    fi
  done
  if [[ -f "${ROOT}/Cargo.lock" ]] && [[ "${ROOT}/Cargo.lock" -nt "$binary" ]]; then
    return 0
  fi
  return 1
}

needs_contract_binary_rebuild() {
  local binary="$1"
  local force_flag="$2"
  shift 2
  [[ ! -x "$binary" ]] && return 0
  if [[ "${!force_flag:-}" == "1" ]]; then
    return 0
  fi
  contract_rust_sources_newer_than "$binary" "$@"
}

# libtest --report-time requires a nightly-built test harness (stable rejects the flag).
ensure_r4_contract_nightly_toolchain() {
  if ! command -v rustup >/dev/null 2>&1; then
    echo "rustup is required to install nightly for R4 contract --report-time" >&2
    exit 1
  fi
  if ! rustup toolchain list | grep -q '^nightly'; then
    echo "==> Installing nightly toolchain for R4 contract slow-test gate"
    rustup toolchain install nightly --profile minimal
  fi
  if ! rustup run nightly cargo --version >/dev/null 2>&1; then
    echo "nightly cargo is unavailable after install" >&2
    exit 1
  fi
}

r4_contract_cargo() {
  ensure_r4_contract_nightly_toolchain
  rustup run nightly cargo "$@"
}

ensure_agrr_server_binary() {
  local host_debug="${ROOT}/target/debug/agrr-server"
  local host_release="${ROOT}/target/release/agrr-server"
  local -a source_dirs=(
    "${ROOT}/crates/agrr-server"
    "${ROOT}/crates/agrr-domain"
    "${ROOT}/crates/agrr-adapters-sqlite"
    "${ROOT}/crates/agrr-adapters-agrr"
    "${ROOT}/crates/agrr-adapters-gcs"
  )

  if [[ "${AGRR_SERVER_CONTRACT_DOCKER_BUILD:-}" == "1" ]] && command -v docker >/dev/null 2>&1; then
    echo "==> Building agrr-server via Dockerfile.agrr-server builder stage (AGRR_SERVER_CONTRACT_DOCKER_BUILD=1)"
    local image cid
    image=$(docker build -q -f Dockerfile.agrr-server --target builder .)
    cid=$(docker create "$image")
    docker cp "${cid}:/app/target/release/agrr-server" "$BINARY"
    docker rm "$cid" >/dev/null
    chmod +x "$BINARY"
    return
  fi

  if [[ -x "$BINARY" ]] && ! needs_contract_binary_rebuild "$BINARY" AGRR_SERVER_CONTRACT_REBUILD "${source_dirs[@]}"; then
    return
  fi
  if [[ -x "$BINARY" ]]; then
    echo "==> agrr-server workspace sources newer than contract binary; rebuilding"
  fi

  if command -v cargo >/dev/null 2>&1; then
  # shellcheck source=/dev/null
    [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
    echo "==> Building agrr-server on host (cargo build -p agrr-server)"
    if cargo build -p agrr-server; then
      if [[ -x "$host_debug" ]]; then
        cp "$host_debug" "$BINARY"
        chmod +x "$BINARY"
        return
      fi
      if [[ -x "$host_release" ]]; then
        cp "$host_release" "$BINARY"
        chmod +x "$BINARY"
        return
      fi
    elif [[ -x "$BINARY" ]]; then
      echo "==> Host cargo build failed; reusing existing contract binary at $BINARY"
      return
    fi
    echo "==> Host cargo build failed; falling back to Dockerfile.agrr-server"
  fi

  echo "==> Building agrr-server via Dockerfile.agrr-server (Debian runtime; matches test container)"
  local image cid
  image=$(docker build -q -f Dockerfile.agrr-server .)
  cid=$(docker create "$image")
  docker cp "${cid}:/usr/local/bin/agrr-server" "$BINARY"
  docker rm "$cid" >/dev/null
  chmod +x "$BINARY"
}

ensure_agrr_server_binary

ensure_agrr_migrate_binary() {
  local host_release="${ROOT}/target/release/agrr-migrate"
  local -a source_dirs=("${ROOT}/crates/agrr-migrate")

  if [[ -x "$MIGRATE_BINARY" ]] && ! needs_contract_binary_rebuild "$MIGRATE_BINARY" AGRR_MIGRATE_CONTRACT_REBUILD "${source_dirs[@]}"; then
    if ! find "${ROOT}/crates/agrr-migrate/migrations" -type f -name '*.sql' -newer "$MIGRATE_BINARY" -print -quit | grep -q .; then
      return
    fi
    echo "==> agrr-migrate embedded SQL newer than contract binary; rebuilding"
  elif [[ -x "$MIGRATE_BINARY" ]]; then
    echo "==> agrr-migrate sources newer than contract binary; rebuilding"
  fi

  if command -v cargo >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
    echo "==> Building agrr-migrate on host (cargo build --release -p agrr-migrate)"
    if cargo build --release -p agrr-migrate; then
      if [[ -x "$host_release" ]]; then
        cp "$host_release" "$MIGRATE_BINARY"
        chmod +x "$MIGRATE_BINARY"
        return
      fi
    elif [[ -x "$MIGRATE_BINARY" ]]; then
      echo "==> Host cargo build failed; reusing existing agrr-migrate at $MIGRATE_BINARY"
      return
    fi
    echo "==> agrr-migrate build failed and no cached binary"
    exit 1
  fi

  if [[ ! -x "$MIGRATE_BINARY" ]]; then
    echo "==> cargo not found and no agrr-migrate binary at $MIGRATE_BINARY"
    exit 1
  fi
}

ensure_agrr_migrate_binary

copy_r4_contract_test_binary_from_deps() {
  local host_built
  host_built="$(find "${ROOT}/target/debug/deps" -maxdepth 1 -name 'contracts-*' -type f ! -name '*.d' -executable 2>/dev/null | head -1)"
  if [[ -z "$host_built" ]]; then
    host_built="$(find "${ROOT}/target/debug/build/agrr-r4-contract" -path '*/out/contracts-*' -type f ! -name '*.d' -executable 2>/dev/null | head -1)"
  fi
  if [[ -n "$host_built" && -x "$host_built" ]]; then
    cp "$host_built" "$R4_CONTRACT_TESTS_BIN"
    chmod +x "$R4_CONTRACT_TESTS_BIN"
    return 0
  fi
  return 1
}

build_r4_contract_tests_on_host() {
  # shellcheck source=/dev/null
  [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
  echo "==> Building agrr-r4-contract tests on host (cargo +nightly test -Z unstable-options --no-run)"
  r4_contract_cargo test -Z unstable-options -p agrr-r4-contract --test contracts --no-run
}

ensure_agrr_r4_contract_tests_binary() {
  local -a source_dirs=("${ROOT}/crates/agrr-r4-contract")

  if [[ -x "$R4_CONTRACT_TESTS_BIN" ]] && ! needs_contract_binary_rebuild "$R4_CONTRACT_TESTS_BIN" AGRR_R4_CONTRACT_REBUILD "${source_dirs[@]}"; then
    return
  fi
  if [[ -x "$R4_CONTRACT_TESTS_BIN" ]]; then
    echo "==> agrr-r4-contract sources newer than contract test binary; rebuilding"
  fi

  # CI (AGRR_SERVER_CONTRACT_DOCKER_BUILD=1): build in bookworm-compatible container so the
  # binary matches the Debian test image glibc (host Ubuntu builds need GLIBC_2.39+).
  if [[ "${AGRR_SERVER_CONTRACT_DOCKER_BUILD:-}" == "1" ]] && command -v docker >/dev/null 2>&1; then
    echo "==> Building agrr-r4-contract tests in rustlang/rust:nightly-bookworm (--report-time harness)"
    docker run --rm \
      -v "${ROOT}:/app" \
      -w /app \
      rustlang/rust:nightly-bookworm \
      cargo +nightly test -Z unstable-options -p agrr-r4-contract --test contracts --no-run
    if copy_r4_contract_test_binary_from_deps; then
      return
    fi
    echo "==> agrr-r4-contract docker build did not produce a test binary"
    exit 1
  fi

  if command -v cargo >/dev/null 2>&1; then
    if build_r4_contract_tests_on_host && copy_r4_contract_test_binary_from_deps; then
      return
    fi
    if [[ -x "$R4_CONTRACT_TESTS_BIN" ]]; then
      echo "==> Host cargo build failed; reusing existing agrr-r4-contract test binary"
      return
    fi
  fi

  if [[ ! -x "$R4_CONTRACT_TESTS_BIN" ]]; then
    echo "==> cargo not found and no agrr-r4-contract test binary at $R4_CONTRACT_TESTS_BIN"
    exit 1
  fi
  echo "==> agrr-r4-contract build failed and no cached test binary"
  exit 1
}

ensure_agrr_r4_contract_tests_binary

echo "==> ensure-reference-fixtures (shell contract)"
bash "${ROOT}/scripts/ensure-reference-fixtures-test.sh"

echo "==> R4 contract (CONTRACT_RUNTIME=rust, shared test.sqlite3)"
R4_LOG_DIR="${ROOT}/tmp/agrr-r4-contract-logs"
R4_LOG="${R4_LOG_DIR}/agrr-r4-contract-tests.log"
mkdir -p "$R4_LOG_DIR"
: >"$R4_LOG"
docker compose --profile test run --rm \
  -e AGRR_TEST_SCRIPT=1 \
  -e "COVERAGE=${COVERAGE:-false}" \
  -e CONTRACT_RUNTIME=rust \
  -e RUST_CONTRACT_BASE_URL=http://127.0.0.1:8080 \
  -v "${BINARY}:/usr/local/bin/agrr-server:ro" \
  -v "${MIGRATE_BINARY}:/usr/local/bin/agrr-migrate:ro" \
  -v "${R4_CONTRACT_TESTS_BIN}:/usr/local/bin/agrr-r4-contract-tests:ro" \
  -v "${R4_LOG_DIR}:/contract-logs:rw" \
  test bash -c '
    set -euo pipefail
    export AGRR_APP_ROOT=/app
    export AGRR_SQLITE_PATH=/app/storage/test.sqlite3
    export AGRR_CACHE_SQLITE_PATH=/app/storage/test_cache.sqlite3
    export PORT=8080
    echo "==> Applying pending schema migrations (host agrr-migrate)"
    agrr-migrate schema run
    export SCHEDULER_AUTH_TOKEN="${SCHEDULER_AUTH_TOKEN:-test_scheduler_token_contract}"
    export AGRR_BACKDOOR_TOKEN="${AGRR_BACKDOOR_TOKEN:-contract-token}"
    export WEATHER_DATA_STORAGE=gcs
    export GCS_BUCKET="${GCS_BUCKET:-test-bucket-contract}"
    export WEATHER_DATA_LOCAL_ROOT="${WEATHER_DATA_LOCAL_ROOT:-/tmp/agrr-weather-contract}"
    mkdir -p "$WEATHER_DATA_LOCAL_ROOT"
    python3 -c "
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        self.rfile.read(length)
        body = json.dumps({'success': True}).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

HTTPServer(('127.0.0.1', 9191), Handler).serve_forever()
" >/tmp/recaptcha-mock.log 2>&1 &
    RECAPTCHA_MOCK_PID=$!
    export RECAPTCHA_SECRET_KEY="${RECAPTCHA_SECRET_KEY:-contract-test-recaptcha-secret}"
    export RECAPTCHA_VERIFY_URL="${RECAPTCHA_VERIFY_URL:-http://127.0.0.1:9191/siteverify}"
    AGRR_BIN="${AGRR_BIN_PATH:-/app/lib/core/agrr}"
    AGRR_SOCKET_PATH="${AGRR_SOCKET_PATH:-/tmp/agrr.sock}"
    if [ -x "$AGRR_BIN" ]; then
      echo "==> Starting agrr daemon for contract regeneration tests"
      "$AGRR_BIN" daemon start || true
      for _ in $(seq 1 100); do
        if [ -S "$AGRR_SOCKET_PATH" ] || [ -e "$AGRR_SOCKET_PATH" ]; then
          break
        fi
        sleep 0.05
      done
    fi
    agrr-server >/tmp/agrr-server-contract.log 2>&1 &
    SERVER_PID=$!
    cleanup() {
      kill "$SERVER_PID" 2>/dev/null || true
      kill "$RECAPTCHA_MOCK_PID" 2>/dev/null || true
    }
    trap cleanup EXIT
    for _ in $(seq 1 50); do
      if curl -sf http://127.0.0.1:8080/health >/dev/null; then
        break
      fi
      sleep 0.1
    done
    if ! curl -sf http://127.0.0.1:8080/health >/dev/null; then
      echo "agrr-server failed to start; log:"
      cat /tmp/agrr-server-contract.log
      exit 1
    fi
    echo "==> contact_messages fail-closed when RECAPTCHA_SECRET_KEY unset (shell contract)"
    env -u RECAPTCHA_SECRET_KEY -u RECAPTCHA_VERIFY_URL \
      AGRR_APP_ROOT=/app \
      AGRR_SQLITE_PATH=/app/storage/test.sqlite3 \
      AGRR_CACHE_SQLITE_PATH=/app/storage/test_cache.sqlite3 \
      PORT=8089 \
      SCHEDULER_AUTH_TOKEN="$SCHEDULER_AUTH_TOKEN" \
      AGRR_BACKDOOR_TOKEN="$AGRR_BACKDOOR_TOKEN" \
      WEATHER_DATA_STORAGE=gcs \
      GCS_BUCKET="$GCS_BUCKET" \
      WEATHER_DATA_LOCAL_ROOT="$WEATHER_DATA_LOCAL_ROOT" \
      agrr-server >/tmp/agrr-server-contract-unconfigured-recaptcha.log 2>&1 &
    UNCONFIGURED_SERVER_PID=$!
    for _ in $(seq 1 50); do
      if curl -sf http://127.0.0.1:8089/health >/dev/null; then
        break
      fi
      sleep 0.1
    done
    UNCONFIGURED_STATUS=$(curl -s -o /tmp/contact-unconfigured-recaptcha.json -w "%{http_code}" \
      -H "Content-Type: application/json" \
      -H "x-forwarded-for: 203.0.113.250" \
      -d '{"email":"unconfigured-recaptcha@example.com","message":"contract shell check","recaptcha_token":"token"}' \
      http://127.0.0.1:8089/api/v1/contact_messages)
    kill "$UNCONFIGURED_SERVER_PID" 2>/dev/null || true
    if [ "$UNCONFIGURED_STATUS" != "503" ]; then
      echo "expected 503 when RECAPTCHA_SECRET_KEY unset, got $UNCONFIGURED_STATUS"
      cat /tmp/contact-unconfigured-recaptcha.json
      cat /tmp/agrr-server-contract-unconfigured-recaptcha.log
      exit 1
    fi
    echo "==> R4 contract (agrr-r4-contract)"
    R4_LOG=/contract-logs/agrr-r4-contract-tests.log
    set +e
    RUST_CONTRACT_BASE_URL=http://127.0.0.1:8080 /usr/local/bin/agrr-r4-contract-tests -Z unstable-options --report-time --test-threads=1 2>&1 | tee "$R4_LOG"
    R4_EXIT=${PIPESTATUS[0]}
    set -e
    exit "$R4_EXIT"
  '

if ! command -v node >/dev/null 2>&1; then
  echo "node is required to run R4 contract slow-test gate (check-slow-libtest-output-cli.mjs)" >&2
  exit 1
fi
node "${ROOT}/scripts/check-slow-libtest-output-cli.mjs" "$R4_LOG"
