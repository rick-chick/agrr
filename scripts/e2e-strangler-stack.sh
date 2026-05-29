#!/usr/bin/env bash
# agrr-server (8080) + nginx strangler (3000) for Angular E2E. Mock login is Rust-only on /auth/test/.
# Optional Rails on 3001 when AGRR_RUST_API is unset (legacy); Playwright uses E2E_STRANGLER=1 and skips Rails.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PID_DIR="${TMPDIR:-/tmp}/agrr-strangler-pids"
mkdir -p "$PID_DIR"
NGINX_CONF="$ROOT/docker/nginx-strangler-host.conf"
NGINX_PID="/tmp/agrr-strangler-nginx.pid"

stop_all() {
  if [[ -f "$NGINX_PID" ]]; then
    nginx -s stop -c "$NGINX_CONF" 2>/dev/null || kill "$(cat "$NGINX_PID")" 2>/dev/null || true
    rm -f "$NGINX_PID"
  fi
  for f in "$PID_DIR"/*.pid; do
    [[ -f "$f" ]] || continue
    kill "$(cat "$f")" 2>/dev/null || true
    rm -f "$f"
  done
}

if [[ "${1:-}" == "stop" ]]; then
  stop_all
  echo "Stopped strangler stack."
  exit 0
fi

stop_all

export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"
export FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:4200,http://localhost:4200}"

if [[ ! -f "$AGRR_SQLITE_PATH" ]]; then
  echo "Missing $AGRR_SQLITE_PATH — run: bundle exec rails db:prepare"
  exit 1
fi

echo "==> cargo build -p agrr-server (release)"
cargo build -q -p agrr-server --release

if [[ "${AGRR_RUST_API:-}" != "1" ]]; then
  echo "==> Rails on 127.0.0.1:3001 (set AGRR_RUST_API=1 for rust-only / no API fallback)"
  FRONTEND_URL="$FRONTEND_URL" bundle exec rails server -b 127.0.0.1 -p 3001 -e development \
    >"$PID_DIR/rails.log" 2>&1 &
  echo $! >"$PID_DIR/rails.pid"
else
  echo "==> Rust-only mode (AGRR_RUST_API=1): skipping Rails — API/auth/cable on agrr-server only"
  rm -f "$PID_DIR/rails.pid"
fi

echo "==> agrr-server on 127.0.0.1:8080"
# Mock login requires non-production AGRR_ENV (see runtime_env.rs).
AGRR_ENV="${AGRR_ENV:-${RAILS_ENV:-development}}" \
  FRONTEND_URL="$FRONTEND_URL" \
  AGRR_SQLITE_PATH="$AGRR_SQLITE_PATH" \
  "$ROOT/target/release/agrr-server" >"$PID_DIR/rust.log" 2>&1 &
echo $! >"$PID_DIR/rust.pid"

for i in $(seq 1 90); do
  rust_ok=0
  curl -sf "http://127.0.0.1:8080/health" >/dev/null && rust_ok=1
  if [[ "${AGRR_RUST_API:-}" == "1" ]]; then
    [[ "$rust_ok" -eq 1 ]] && break
  else
    curl -sf "http://127.0.0.1:3001/up" >/dev/null && [[ "$rust_ok" -eq 1 ]] && break
  fi
  sleep 1
done

if ! curl -sf "http://127.0.0.1:8080/health" >/dev/null; then
  echo "agrr-server failed; see $PID_DIR/rust.log"
  tail -30 "$PID_DIR/rust.log" || true
  stop_all
  exit 1
fi

echo "==> nginx strangler on 127.0.0.1:3000"
nginx -c "$NGINX_CONF" -g "pid $NGINX_PID; daemon on; error_log $PID_DIR/nginx-error.log;"
sleep 1

if ! curl -sf "http://127.0.0.1:3000/health" >/dev/null; then
  echo "nginx strangler failed; see $PID_DIR/nginx.log"
  stop_all
  exit 1
fi

echo "Stack ready."
echo "  API (strangler): http://127.0.0.1:3000"
echo "  Angular:         http://127.0.0.1:4200"
echo "  E2E:  cd frontend && E2E_STRANGLER=1 E2E_CAPTURE_DEV_SESSION=1 E2E_API_ORIGIN=http://127.0.0.1:3000 npx playwright test ..."
echo "Stop: $0 stop"
