#!/usr/bin/env bash
# ローカル Rust 開発の唯一の起動入口: agrr デーモン + agrr-server (:8080) + nginx (:3000 → Rust).
# Angular (ng serve :4200) は API/WebSocket を http://127.0.0.1:3000 に向ける。
#
#   ./scripts/dev-rust-stack.sh        # 起動
#   ./scripts/dev-rust-stack.sh stop   # 停止
#
# 環境変数: AGRR_SQLITE_PATH, AGRR_SOCKET_PATH, AGRR_BIN, AGRR_USE_MOCK, AGRR_SKIP_CARGO_BUILD, WEATHER_DATA_SOURCE
set -euo pipefail

export AGRR_RUST_API=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

resolve_cargo() {
  if command -v cargo >/dev/null 2>&1; then
    command -v cargo
    return 0
  fi
  if [[ -x "${HOME}/.cargo/bin/cargo" ]]; then
    echo "${HOME}/.cargo/bin/cargo"
    return 0
  fi
  return 1
}

PID_DIR="${TMPDIR:-/tmp}/agrr-dev-rust-pids"
mkdir -p "$PID_DIR"
NGINX_CONF="$ROOT/docker/nginx-strangler-host.conf"
NGINX_PID="/tmp/agrr-dev-rust-nginx.pid"
# 旧 alias スクリプト削除済み — 本スクリプトを直接使う
LEGACY_NGINX_PID="/tmp/agrr-strangler-nginx.pid"
LEGACY_PID_DIR="${TMPDIR:-/tmp}/agrr-strangler-pids"

port_listening() {
  local port="$1"
  ss -tln 2>/dev/null | grep -q ":${port} "
}

stop_nginx_strangler() {
  nginx -s stop -c "$NGINX_CONF" 2>/dev/null || true
  for pid_file in "$NGINX_PID" "$LEGACY_NGINX_PID"; do
    if [[ -f "$pid_file" ]]; then
      kill "$(cat "$pid_file")" 2>/dev/null || true
      rm -f "$pid_file"
    fi
  done
  if command -v pgrep >/dev/null 2>&1; then
    local pid
    while IFS= read -r pid; do
      [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done < <(pgrep -f "nginx: master process.*nginx-strangler-host" 2>/dev/null || true)
  fi
}

stop_all() {
  stop_nginx_strangler
  for dir in "$PID_DIR" "$LEGACY_PID_DIR"; do
    for f in "$dir"/*.pid; do
      [[ -f "$f" ]] || continue
      kill "$(cat "$f")" 2>/dev/null || true
      rm -f "$f"
    done
  done
  if [[ -f "$PID_DIR/rust.pid" ]]; then
    kill "$(cat "$PID_DIR/rust.pid")" 2>/dev/null || true
    rm -f "$PID_DIR/rust.pid"
  fi
}

require_port_free() {
  local port="$1"
  local label="$2"
  if ! port_listening "$port"; then
    return 0
  fi
  echo "==> Port ${port} (${label}) is in use; stopping leftover dev Rust stack processes..."
  stop_nginx_strangler
  if [[ "$port" == "8080" ]] && [[ -f "$PID_DIR/rust.pid" ]]; then
    kill "$(cat "$PID_DIR/rust.pid")" 2>/dev/null || true
    rm -f "$PID_DIR/rust.pid"
  fi
  sleep 1
  if port_listening "$port"; then
    echo "ERROR: port ${port} still in use. Another process (e.g. docker compose web on :3000) may be bound."
    ss -tlnp 2>/dev/null | grep ":${port} " || true
    echo "Free the port, then re-run: ./scripts/dev-rust-stack.sh"
    return 1
  fi
}

if [[ "${1:-}" == "stop" ]]; then
  stop_all
  echo "Stopped dev Rust stack."
  exit 0
fi

stop_all

export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"
export FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:4200,http://localhost:4200}"

if [[ ! -f "$AGRR_SQLITE_PATH" ]]; then
  echo "Missing $AGRR_SQLITE_PATH — run once: RAILS_ENV=development bundle exec rails db:prepare"
  exit 1
fi

export AGRR_SOCKET_PATH="${AGRR_SOCKET_PATH:-/tmp/agrr.sock}"
# docker-compose / env.example と同じ。India 等は noaa より nasa-power（determine_data_source の noaa を上書き）
export WEATHER_DATA_SOURCE="${WEATHER_DATA_SOURCE:-nasa-power}"
AGRR_BIN="${AGRR_BIN:-$ROOT/lib/core/agrr}"

ensure_agrr_daemon() {
  if [[ -S "$AGRR_SOCKET_PATH" ]]; then
    return 0
  fi
  if [[ ! -x "$AGRR_BIN" ]]; then
    echo "agrr binary missing at $AGRR_BIN (build lib/core/agrr or set AGRR_BIN)"
    exit 1
  fi
  echo "==> Starting agrr daemon ($AGRR_BIN)"
  if ! "$AGRR_BIN" daemon start >/dev/null 2>&1; then
    echo "agrr daemon start failed (check $AGRR_BIN daemon status)"
    exit 1
  fi
  for _ in $(seq 1 45); do
    [[ -S "$AGRR_SOCKET_PATH" ]] && return 0
    sleep 1
  done
  echo "agrr daemon did not create $AGRR_SOCKET_PATH"
  exit 1
}

ensure_agrr_daemon

AGRR_SERVER_BIN="$ROOT/target/release/agrr-server"
if [[ "${AGRR_SKIP_CARGO_BUILD:-}" == "1" && -x "$AGRR_SERVER_BIN" ]]; then
  echo "==> skip cargo build (AGRR_SKIP_CARGO_BUILD=1, using $AGRR_SERVER_BIN)"
else
  CARGO="$(resolve_cargo)" || {
    echo "cargo not found. Install Rust:"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo "  source \"\$HOME/.cargo/env\""
    echo "Or skip rebuild if binary exists:"
    echo "  AGRR_SKIP_CARGO_BUILD=1 ./scripts/dev-rust-stack.sh"
    exit 1
  }
  echo "==> cargo build -p agrr-server (release) ($CARGO)"
  "$CARGO" build -q -p agrr-server --release
fi

require_port_free 8080 "agrr-server" || exit 1

echo "==> agrr-server on 127.0.0.1:8080 (AGRR_USE_MOCK=${AGRR_USE_MOCK:-false}, WEATHER_DATA_SOURCE=$WEATHER_DATA_SOURCE, socket=$AGRR_SOCKET_PATH)"
AGRR_ENV="${AGRR_ENV:-development}" \
  FRONTEND_URL="$FRONTEND_URL" \
  AGRR_SQLITE_PATH="$AGRR_SQLITE_PATH" \
  AGRR_SOCKET_PATH="$AGRR_SOCKET_PATH" \
  AGRR_USE_MOCK="${AGRR_USE_MOCK:-false}" \
  WEATHER_DATA_SOURCE="$WEATHER_DATA_SOURCE" \
  "$ROOT/target/release/agrr-server" >"$PID_DIR/rust.log" 2>&1 &
echo $! >"$PID_DIR/rust.pid"

for _ in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:8080/health" >/dev/null; then
    break
  fi
  sleep 1
done

if ! curl -sf "http://127.0.0.1:8080/health" >/dev/null; then
  echo "agrr-server failed; see $PID_DIR/rust.log"
  tail -30 "$PID_DIR/rust.log" || true
  stop_all
  exit 1
fi

require_port_free 3000 "nginx strangler" || { stop_all; exit 1; }

echo "==> nginx on 127.0.0.1:3000 (API/auth/cable → agrr-server)"
nginx -c "$NGINX_CONF" -g "pid $NGINX_PID; daemon on; error_log $PID_DIR/nginx-error.log;"
sleep 1

if ! curl -sf "http://127.0.0.1:3000/health" >/dev/null; then
  echo "nginx failed; see $PID_DIR/nginx-error.log"
  stop_all
  exit 1
fi

echo ""
echo "Dev Rust stack ready."
echo "  API + WebSocket: http://127.0.0.1:3000"
echo "  agrr-server:     http://127.0.0.1:8080/health"
echo "  Angular:         cd frontend && ng serve --host 127.0.0.1   # → :4200, API は :3000"
echo "  Stop:            ./scripts/dev-rust-stack.sh stop"
echo "  Logs:            $PID_DIR/rust.log"
