#!/usr/bin/env bash
# Rust 最適化チェーンのローカル確認（agrr デーモン + development.sqlite3 + spike / 任意で E2E チェーン）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

export AGRR_SQLITE_PATH="${AGRR_SQLITE_PATH:-$ROOT/storage/development.sqlite3}"
export AGRR_SOCKET_PATH="${AGRR_SOCKET_PATH:-/tmp/agrr.sock}"
export AGRR_USE_MOCK="${AGRR_USE_MOCK:-false}"
PLAN_ID="${PLAN_ID:-14}"
RUN_CHAIN="${RUN_CHAIN:-0}"
CHAIN_TIMEOUT="${CHAIN_RUN_TIMEOUT_SEC:-120}"

fail() {
  echo "verify-rust-optimization-chain: ERROR: $*" >&2
  exit 1
}

echo "== Rust optimization chain verify =="
echo "  AGRR_SQLITE_PATH=$AGRR_SQLITE_PATH"
echo "  AGRR_SOCKET_PATH=$AGRR_SOCKET_PATH"
echo "  AGRR_USE_MOCK=$AGRR_USE_MOCK"
echo "  PLAN_ID=$PLAN_ID"
echo "  RUN_CHAIN=$RUN_CHAIN"
echo

[[ -f "$AGRR_SQLITE_PATH" ]] || fail "DB missing. Run: bundle exec rails db:prepare (or copy development.sqlite3)"

if [[ ! -S "$AGRR_SOCKET_PATH" ]]; then
  fail "agrr daemon not running at $AGRR_SOCKET_PATH. Example: USE_AGRR_DAEMON=true docker compose up"
fi

command -v cargo >/dev/null 2>&1 || fail "cargo not found (install rustup / source ~/.cargo/env)"

echo ">> cargo build (agrr-server bins)"
cargo build -q -p agrr-server --bins

echo ">> optimization-chain-spike"
if ! cargo run -q -p agrr-server --bin optimization-chain-spike -- --plan-id "$PLAN_ID"; then
  fail "spike failed (see output above)"
fi

if [[ "$RUN_CHAIN" == "1" ]]; then
  echo ">> reset plan $PLAN_ID for chain run"
  sqlite3 "$AGRR_SQLITE_PATH" <<SQL
UPDATE cultivation_plans
SET status = 'optimizing',
    optimization_phase = NULL,
    optimization_phase_message = NULL,
    predicted_weather_data = NULL,
    updated_at = datetime('now')
WHERE id = $PLAN_ID;
DELETE FROM field_cultivations WHERE cultivation_plan_id = $PLAN_ID;
SQL

  echo ">> optimization-chain-run (timeout ${CHAIN_TIMEOUT}s)"
  export CHAIN_RUN_TIMEOUT_SEC="$CHAIN_TIMEOUT"
  if ! cargo run -q -p agrr-server --bin optimization-chain-run -- --plan-id "$PLAN_ID"; then
    fail "chain run failed"
  fi

  echo ">> plan status"
  sqlite3 -header -column "$AGRR_SQLITE_PATH" \
    "SELECT id, status, optimization_phase,
            (SELECT COUNT(*) FROM field_cultivations WHERE cultivation_plan_id = $PLAN_ID) AS field_cultivations
     FROM cultivation_plans WHERE id = $PLAN_ID;"
fi

echo
echo "OK: Rust optimization chain is verifiable locally."
echo "  Spike only:  bash scripts/verify-rust-optimization-chain.sh"
echo "  Full chain:  RUN_CHAIN=1 bash scripts/verify-rust-optimization-chain.sh"
echo "  UI + API:    ./scripts/dev-rust-stack.sh  (agrr-server :8080, nginx :3000)"
