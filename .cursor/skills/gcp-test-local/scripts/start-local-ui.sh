#!/usr/bin/env bash
# Start ng serve (gcp-test) on 127.0.0.1:4201 — proxy to Cloud Run agrr-test.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "ERROR: repository root not found (git rev-parse failed)" >&2
  exit 1
fi

HOST="${GCP_TEST_UI_HOST:-127.0.0.1}"
PORT="${GCP_TEST_UI_PORT:-4201}"
PROJECT_ID="${PROJECT_ID:-agrr-475323}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE_NAME:-agrr-test}"
HEALTH_URL="http://${HOST}:${PORT}/api/v1/health"
LOG="${PROJECT_ROOT}/tmp/gcp-test-ng-serve.log"
PID_FILE="${PROJECT_ROOT}/tmp/gcp-test-ng-serve.pid"

mkdir -p "${PROJECT_ROOT}/tmp"

if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
  echo "==> GCP test UI already up: http://${HOST}:${PORT}"
  exit 0
fi

if [ -f "$PID_FILE" ]; then
  old_pid="$(cat "$PID_FILE")"
  if kill -0 "$old_pid" 2>/dev/null; then
    echo "==> Stopping stale ng serve (pid $old_pid)"
    kill "$old_pid" 2>/dev/null || true
    sleep 1
  fi
  rm -f "$PID_FILE"
fi

if [ -z "${AGRR_TEST_API_URL:-}" ]; then
  AGRR_TEST_API_URL="$(gcloud run services describe "$SERVICE" \
    --region "$REGION" --project "$PROJECT_ID" --format='value(status.url)')"
fi
export AGRR_TEST_API_URL

echo "==> Starting ng serve (gcp-test) → ${AGRR_TEST_API_URL}"
echo "==> Log: ${LOG}"
cd "${PROJECT_ROOT}/frontend"
nohup env AGRR_TEST_API_URL="$AGRR_TEST_API_URL" npx ng serve \
  --configuration gcp-test \
  --host "$HOST" \
  --port "$PORT" \
  >>"$LOG" 2>&1 &
echo $! >"$PID_FILE"

for _ in $(seq 1 90); do
  if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
    echo "==> http://${HOST}:${PORT}"
    exit 0
  fi
  sleep 2
done

echo "ERROR: ng serve did not become ready (see ${LOG})" >&2
exit 1
