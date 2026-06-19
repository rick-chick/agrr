#!/usr/bin/env bash
# Wait until docker compose dev stack (agrr-server + strangler-proxy) is reachable.
# Used by frontend-e2e-smoke CI and documented in frontend/e2e/smoke/README.md.
set -euo pipefail

API_ORIGIN="${1:-http://127.0.0.1:3000}"
API_ORIGIN="${API_ORIGIN%/}"
MAX_WAIT_SEC="${CI_WAIT_SMOKE_STACK_SEC:-180}"

deadline=$((SECONDS + MAX_WAIT_SEC))
while (( SECONDS < deadline )); do
  if curl -sf "${API_ORIGIN}/health" >/dev/null 2>&1 || curl -sf "${API_ORIGIN}/up" >/dev/null 2>&1; then
    echo "ci-wait-smoke-stack: ready at ${API_ORIGIN}"
    exit 0
  fi
  sleep 2
done

echo "ci-wait-smoke-stack: timed out after ${MAX_WAIT_SEC}s waiting for ${API_ORIGIN}/health or /up" >&2
exit 1
