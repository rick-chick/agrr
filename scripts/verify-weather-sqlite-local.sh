#!/usr/bin/env bash
# Local check: weather bulk in SQLite (active_record) + scheduler incremental window (latest+1).
# Uses a DB separate from storage/development.sqlite3 by default.
#
# Usage:
#   ./scripts/verify-weather-sqlite-local.sh prepare
#   ./scripts/verify-weather-sqlite-local.sh env        # print exports
#   ./scripts/verify-weather-sqlite-local.sh status
#   .cursor/skills/dev-docker/scripts/up.sh   # or host-rust-stack.sh
#   ./scripts/verify-weather-sqlite-local.sh server     # headless only (UI は dev-docker)
#   ./scripts/verify-weather-sqlite-local.sh trigger
#   ./scripts/verify-weather-sqlite-local.sh verify     # prepare + 2x trigger + checks
#   ./scripts/verify-weather-sqlite-local.sh stop       # stop background server from `server`
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

PLAY_DB="${AGRR_SQLITE_PATH:-/tmp/agrr-weather-play.sqlite3}"
export AGRR_SQLITE_PATH="$PLAY_DB"
export AGRR_PRIMARY_SQLITE_PATH="$PLAY_DB"
export WEATHER_DATA_STORAGE="${WEATHER_DATA_STORAGE:-active_record}"
export SCHEDULER_AUTH_TOKEN="${SCHEDULER_AUTH_TOKEN:-dev-weather-play-token}"
export AGRR_ENV="${AGRR_ENV:-development}"
export AGRR_SOCKET_PATH="${AGRR_SOCKET_PATH:-/tmp/agrr.sock}"
RUST_URL="${RUST_URL:-http://127.0.0.1:8080}"
WAIT_SEC="${WAIT_SEC:-180}"
PID_DIR="${TMPDIR:-/tmp}/agrr-weather-play-pids"
mkdir -p "$PID_DIR"
SERVER_PID_FILE="$PID_DIR/agrr-server.pid"
SERVER_LOG="$PID_DIR/agrr-server.log"
AGRR_BIN="${AGRR_BIN:-$ROOT/lib/core/agrr}"

fail() {
  echo "verify-weather-sqlite-local: ERROR: $*" >&2
  exit 1
}

info() {
  echo "verify-weather-sqlite-local: $*"
}

need_sqlite3() {
  command -v sqlite3 >/dev/null 2>&1 || fail "sqlite3 not found"
}

need_curl() {
  command -v curl >/dev/null 2>&1 || fail "curl not found"
}

ensure_agrr_daemon() {
  if [[ -S "$AGRR_SOCKET_PATH" ]]; then
    return 0
  fi
  [[ -x "$AGRR_BIN" ]] || fail "agrr daemon not running and $AGRR_BIN missing. Try: dev-docker/scripts/up.sh"
  info "starting agrr daemon ($AGRR_BIN)"
  "$AGRR_BIN" daemon start >/dev/null 2>&1 || true
  for _ in $(seq 1 45); do
    [[ -S "$AGRR_SOCKET_PATH" ]] && return 0
    sleep 1
  done
  fail "agrr daemon did not create $AGRR_SOCKET_PATH"
}

cmd_prepare() {
  need_sqlite3
  if [[ -f "$PLAY_DB" ]]; then
    info "play DB already exists: $PLAY_DB"
    return 0
  fi
  [[ -f "$ROOT/storage/development.sqlite3" ]] || fail "missing storage/development.sqlite3 — run: dev-docker/scripts/load-reference-data-host.sh"
  cp "$ROOT/storage/development.sqlite3" "$PLAY_DB"
  info "copied development.sqlite3 -> $PLAY_DB (development DB untouched)"
}

pick_farm_row() {
  need_sqlite3
  [[ -f "$PLAY_DB" ]] || fail "play DB missing — run: $0 prepare"
  sqlite3 -separator '|' "$PLAY_DB" "
    SELECT f.id, f.weather_location_id, f.latitude, f.longitude
    FROM farms f
    WHERE f.is_reference = 0
      AND f.weather_location_id IS NOT NULL
      AND f.latitude IS NOT NULL
      AND f.longitude IS NOT NULL
    ORDER BY f.id
    LIMIT 1;
  "
}

weather_stats() {
  local wl_id="$1"
  sqlite3 -separator '|' "$PLAY_DB" "
    SELECT
      COUNT(*),
      COALESCE(MIN(date), ''),
      COALESCE(MAX(date), '')
    FROM weather_data
    WHERE weather_location_id = $wl_id;
  "
}

cmd_env() {
  cat <<EOF
# Isolated SQLite weather play (development DB not used when both are set)
export AGRR_SQLITE_PATH=$PLAY_DB
export AGRR_PRIMARY_SQLITE_PATH=$PLAY_DB
export WEATHER_DATA_STORAGE=active_record
export SCHEDULER_AUTH_TOKEN=$SCHEDULER_AUTH_TOKEN
export AGRR_SOCKET_PATH=$AGRR_SOCKET_PATH
export AGRR_ENV=$AGRR_ENV

# agrr-server (after: $0 server  OR  docker compose + rust stack)
# RUST_URL=$RUST_URL
EOF
}

cmd_status() {
  cmd_prepare
  need_sqlite3
  local row
  row="$(pick_farm_row)" || true
  [[ -n "$row" ]] || fail "no user farm with weather_location — create one in play DB or re-copy from development"
  IFS='|' read -r farm_id wl_id lat lon <<<"$row"
  IFS='|' read -r cnt min_d max_d <<<"$(weather_stats "$wl_id")"
  info "play DB: $PLAY_DB"
  info "WEATHER_DATA_STORAGE=$WEATHER_DATA_STORAGE"
  info "farm_id=$farm_id weather_location_id=$wl_id ($lat, $lon)"
  info "weather_data rows=$cnt min=$min_d max=$max_d"
  if [[ "$WEATHER_DATA_STORAGE" != "active_record" ]]; then
    echo "WARN: bulk will not land in weather_data unless WEATHER_DATA_STORAGE=active_record" >&2
  fi
}

wait_weather_settle() {
  local wl_id="$1"
  local before="$2"
  local stable=0
  local last="$before"
  local deadline=$((SECONDS + WAIT_SEC))
  info "waiting up to ${WAIT_SEC}s for weather_data rows to settle (wl_id=$wl_id)..."
  while [[ "$SECONDS" -lt "$deadline" ]]; do
    IFS='|' read -r cur _ _ <<<"$(weather_stats "$wl_id")"
    if [[ "$cur" == "$last" ]]; then
      stable=$((stable + 1))
      [[ "$stable" -ge 3 ]] && break
    else
      stable=0
      last="$cur"
    fi
    sleep 2
  done
  IFS='|' read -r cur min_d max_d <<<"$(weather_stats "$wl_id")"
  info "after wait: rows=$cur min=$min_d max=$max_d (was $before)"
}

cmd_trigger() {
  cmd_prepare
  need_curl
  curl -sf "$RUST_URL/health" >/dev/null || fail "agrr-server not healthy at $RUST_URL — run: $0 server"
  info "POST $RUST_URL/api/v1/internal/jobs/trigger_weather_update"
  curl -sS -X POST "$RUST_URL/api/v1/internal/jobs/trigger_weather_update" \
    -H "X-Scheduler-Token: $SCHEDULER_AUTH_TOKEN"
  echo
}

cmd_server() {
  cmd_prepare
  ensure_agrr_daemon
  command -v cargo >/dev/null 2>&1 || fail "cargo not found"
  if [[ -f "$SERVER_PID_FILE" ]] && kill -0 "$(cat "$SERVER_PID_FILE")" 2>/dev/null; then
    info "agrr-server already running (pid $(cat "$SERVER_PID_FILE"))"
    return 0
  fi
  info "building agrr-server"
  cargo build -q -p agrr-server --release
  info "starting agrr-server on $RUST_URL (log: $SERVER_LOG)"
  WEATHER_DATA_STORAGE="$WEATHER_DATA_STORAGE" \
    AGRR_SQLITE_PATH="$PLAY_DB" \
    AGRR_ENV="$AGRR_ENV" \
    AGRR_SOCKET_PATH="$AGRR_SOCKET_PATH" \
    SCHEDULER_AUTH_TOKEN="$SCHEDULER_AUTH_TOKEN" \
    "$ROOT/target/release/agrr-server" >"$SERVER_LOG" 2>&1 &
  echo $! >"$SERVER_PID_FILE"
  for _ in $(seq 1 60); do
    curl -sf "$RUST_URL/health" >/dev/null && break
    sleep 1
  done
  curl -sf "$RUST_URL/health" >/dev/null || fail "agrr-server failed to start — see $SERVER_LOG"
  info "agrr-server ready"
}

cmd_stop() {
  if [[ -f "$SERVER_PID_FILE" ]]; then
    kill "$(cat "$SERVER_PID_FILE")" 2>/dev/null || true
    rm -f "$SERVER_PID_FILE"
    info "stopped agrr-server"
  fi
}

# Rust: SchedulerUserFarmFetchWindowPolicy (agrr-domain)
expected_scheduler_range() {
  local max_date="${1:-}"
  python3 - "$max_date" <<'PY'
import sys
from datetime import date, timedelta

raw = sys.argv[1] if len(sys.argv) > 1 else ""
today = date.today()
lookback = 7

if raw:
    latest = date.fromisoformat(raw[:10])
    start = latest + timedelta(days=1)
else:
    start = today - timedelta(days=lookback)

if start > today:
    print("skip")
else:
    print(f"start={start.isoformat()} end={today.isoformat()}")
PY
}

cmd_verify() {
  cmd_prepare
  need_sqlite3
  cmd_server
  trap 'cmd_stop' EXIT

  local row farm_id wl_id
  row="$(pick_farm_row)"
  IFS='|' read -r farm_id wl_id _ _ <<<"$row"

  IFS='|' read -r count_before _ max_before <<<"$(weather_stats "$wl_id")"
  info "=== run 1 (scheduler; no latest => ~7 day lookback) ==="
  local range1
  range1="$(expected_scheduler_range "$max_before")"
  info "policy with latest=$max_before => $range1"
  cmd_trigger >/dev/null
  wait_weather_settle "$wl_id" "$count_before"
  IFS='|' read -r count_after1 _ max_after1 <<<"$(weather_stats "$wl_id")"
  [[ "$count_after1" -gt "$count_before" ]] || fail "run 1: expected weather_data rows to increase (active_record + agrr daemon required)"
  info "OK run 1: rows $count_before -> $count_after1 max_date=$max_after1"

  info "=== run 2 (scheduler; latest+1 .. today) ==="
  local range2
  range2="$(expected_scheduler_range "$max_after1")"
  info "policy with latest=$max_after1 => $range2"
  if [[ "$range2" == "skip" ]]; then
    info "OK run 2 skipped by policy (already up to date for today)"
    info "tip: delete recent rows to force incremental, e.g.:"
    echo "  sqlite3 \"$PLAY_DB\" \"DELETE FROM weather_data WHERE weather_location_id=$wl_id AND date >= date('now');\""
    exit 0
  fi
  local count_before2="$count_after1"
  cmd_trigger >/dev/null
  wait_weather_settle "$wl_id" "$count_before2"
  IFS='|' read -r count_after2 _ max_after2 <<<"$(weather_stats "$wl_id")"
  if [[ "$count_after2" -le "$count_before2" ]]; then
    info "run 2: row count unchanged ($count_after2) — may be sufficient data in range (perform skip)"
  else
    info "OK run 2: rows $count_before2 -> $count_after2 max_date=$max_after2"
  fi
  info "expected incremental window: $range2"
  info "full verify done — play DB: $PLAY_DB"
}

usage() {
  cat <<EOF
Usage: $0 <command>

  prepare   Copy development.sqlite3 -> play DB (once)
  env       Print environment exports
  status    Show farm + weather_data stats on play DB
  server    Start agrr-server (release) against play DB
  stop      Stop agrr-server started by 'server'
  trigger   POST trigger_weather_update (server must be up)
  verify    prepare + server + 2x scheduler + row checks

Defaults:
  AGRR_SQLITE_PATH=$PLAY_DB
  WEATHER_DATA_STORAGE=active_record
  RUST_URL=$RUST_URL

Requires agrr daemon at \$AGRR_SOCKET_PATH for actual API fetch.
EOF
}

main() {
  local cmd="${1:-verify}"
  case "$cmd" in
    prepare) cmd_prepare ;;
    env) cmd_env ;;
    status) cmd_status ;;
    server) cmd_server ;;
    stop) cmd_stop ;;
    trigger) cmd_trigger ;;
    verify) cmd_verify ;;
    -h|--help|help) usage ;;
    *) usage; fail "unknown command: $cmd" ;;
  esac
}

main "$@"
