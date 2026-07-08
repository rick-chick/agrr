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

ensure_agrr_r4_contract_tests_binary() {
  local -a source_dirs=("${ROOT}/crates/agrr-r4-contract")
  local host_built=""

  if [[ "${AGRR_SERVER_CONTRACT_DOCKER_BUILD:-}" == "1" ]] && command -v docker >/dev/null 2>&1; then
    echo "==> Building agrr-r4-contract tests in rust:1-bookworm (AGRR_SERVER_CONTRACT_DOCKER_BUILD=1)"
    docker run --rm \
      -v "${ROOT}:/app" \
      -w /app \
      rust:1-bookworm \
      cargo build --tests -p agrr-r4-contract
    host_built="$(find "${ROOT}/target/debug/deps" -maxdepth 1 -name 'contracts-*' -type f ! -name '*.d' -executable 2>/dev/null | head -1)"
    if [[ -n "$host_built" && -x "$host_built" ]]; then
      cp "$host_built" "$R4_CONTRACT_TESTS_BIN"
      chmod +x "$R4_CONTRACT_TESTS_BIN"
      return
    fi
    echo "==> agrr-r4-contract docker build did not produce a test binary"
    exit 1
  fi

  if [[ -x "$R4_CONTRACT_TESTS_BIN" ]] && ! needs_contract_binary_rebuild "$R4_CONTRACT_TESTS_BIN" AGRR_R4_CONTRACT_REBUILD "${source_dirs[@]}"; then
    return
  fi
  if [[ -x "$R4_CONTRACT_TESTS_BIN" ]]; then
    echo "==> agrr-r4-contract sources newer than contract test binary; rebuilding"
  fi

  if command -v cargo >/dev/null 2>&1; then
    # shellcheck source=/dev/null
    [[ -f "${HOME}/.cargo/env" ]] && source "${HOME}/.cargo/env"
    echo "==> Building agrr-r4-contract tests on host (cargo build --tests -p agrr-r4-contract)"
    if cargo build --tests -p agrr-r4-contract; then
      host_built="$(find "${ROOT}/target/debug/deps" -maxdepth 1 -name 'contracts-*' -type f ! -name '*.d' -executable 2>/dev/null | head -1)"
      if [[ -n "$host_built" && -x "$host_built" ]]; then
        cp "$host_built" "$R4_CONTRACT_TESTS_BIN"
        chmod +x "$R4_CONTRACT_TESTS_BIN"
        return
      fi
    elif [[ -x "$R4_CONTRACT_TESTS_BIN" ]]; then
      echo "==> Host cargo build failed; reusing existing agrr-r4-contract test binary"
      return
    fi
    echo "==> agrr-r4-contract build failed and no cached test binary"
    exit 1
  fi

  if [[ ! -x "$R4_CONTRACT_TESTS_BIN" ]]; then
    echo "==> cargo not found and no agrr-r4-contract test binary at $R4_CONTRACT_TESTS_BIN"
    exit 1
  fi
}

ensure_agrr_r4_contract_tests_binary

echo "==> ensure-reference-fixtures (shell contract)"
bash "${ROOT}/scripts/ensure-reference-fixtures-test.sh"

echo "==> R4 contract (CONTRACT_RUNTIME=rust, shared test.sqlite3)"
docker compose --profile test run --rm \
  -e AGRR_TEST_SCRIPT=1 \
  -e "COVERAGE=${COVERAGE:-false}" \
  -e CONTRACT_RUNTIME=rust \
  -e RUST_CONTRACT_BASE_URL=http://127.0.0.1:8080 \
  -v "${BINARY}:/usr/local/bin/agrr-server:ro" \
  -v "${MIGRATE_BINARY}:/usr/local/bin/agrr-migrate:ro" \
  -v "${R4_CONTRACT_TESTS_BIN}:/usr/local/bin/agrr-r4-contract-tests:ro" \
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
    agrr-server >/tmp/agrr-server-contract.log 2>&1 &
    SERVER_PID=$!
    cleanup() { kill "$SERVER_PID" 2>/dev/null || true; }
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
    echo "==> R4 contract (agrr-r4-contract)"
    RUST_CONTRACT_BASE_URL=http://127.0.0.1:8080 /usr/local/bin/agrr-r4-contract-tests
  '
