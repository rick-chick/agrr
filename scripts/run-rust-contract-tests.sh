#!/usr/bin/env bash
# R4 contract tests against co-located agrr-server (same SQLite as Rails test DB).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BINARY="${ROOT}/tmp/agrr-server-contract/agrr-server"
mkdir -p "$(dirname "$BINARY")"

ensure_agrr_server_binary() {
  local host_debug="${ROOT}/target/debug/agrr-server"
  local host_release="${ROOT}/target/release/agrr-server"
  local stamp="${ROOT}/crates/agrr-server/src"

  if [[ -x "$BINARY" ]] && [[ "${AGRR_SERVER_CONTRACT_REBUILD:-}" != "1" ]]; then
    if [[ ! "$stamp" -nt "$BINARY" ]]; then
      return
    fi
    echo "==> agrr-server sources newer than contract binary; rebuilding"
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

echo "==> R4 contract (CONTRACT_RUNTIME=rust, shared test.sqlite3)"
docker compose --profile test run --rm \
  -e AGRR_TEST_SCRIPT=1 \
  -e "COVERAGE=${COVERAGE:-false}" \
  -e CONTRACT_RUNTIME=rust \
  -e RUST_CONTRACT_BASE_URL=http://127.0.0.1:8080 \
  -v "${BINARY}:/usr/local/bin/agrr-server:ro" \
  test bash -c '
    set -euo pipefail
    export AGRR_SQLITE_PATH=/app/storage/test.sqlite3
    export PORT=8080
    export SCHEDULER_AUTH_TOKEN="${SCHEDULER_AUTH_TOKEN:-test_scheduler_token_contract}"
    export AGRR_BACKDOOR_TOKEN="${AGRR_BACKDOOR_TOKEN:-contract-token}"
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
    bundle exec rails test test/contract/
  '
