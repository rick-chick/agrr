#!/bin/bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
FRONTEND_ORIGIN="${FRONTEND_ORIGIN:-http://localhost:4200}"
SESSION_ID="${SESSION_ID:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command not found: $1" >&2
    exit 1
  fi
}

require_command curl

echo "==> Checking API health..."
curl -sSf "${BASE_URL}/api/v1/health" >/dev/null
echo "OK: /api/v1/health"

echo "==> Checking CORS preflight for /api/v1/auth/me..."
cors_headers=$(curl -s -i -X OPTIONS \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  -H "Access-Control-Request-Method: GET" \
  "${BASE_URL}/api/v1/auth/me")

echo "${cors_headers}" | grep -i "access-control-allow-origin: ${FRONTEND_ORIGIN}" >/dev/null
echo "${cors_headers}" | grep -i "access-control-allow-credentials: true" >/dev/null
echo "OK: CORS headers present"

echo "==> Checking unauthenticated /api/v1/auth/me returns 401..."
status_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  "${BASE_URL}/api/v1/auth/me")

if [ "${status_code}" != "401" ]; then
  echo "ERROR: Expected 401, got ${status_code}" >&2
  exit 1
fi
echo "OK: Unauthenticated /api/v1/auth/me is 401"

if [ -z "${SESSION_ID}" ]; then
  echo "ERROR: SESSION_ID is required for authenticated checks." >&2
  echo "Set SESSION_ID from the browser cookie after login." >&2
  exit 1
fi

cookie_header="session_id=${SESSION_ID}"

echo "==> Checking authenticated /api/v1/auth/me returns 200..."
status_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  -H "Cookie: ${cookie_header}" \
  "${BASE_URL}/api/v1/auth/me")

if [ "${status_code}" != "200" ]; then
  echo "ERROR: Expected 200, got ${status_code}" >&2
  exit 1
fi
echo "OK: Authenticated /api/v1/auth/me is 200"

echo "==> Checking /api/v1/auth/logout invalidates session..."
curl -s -o /dev/null -w "%{http_code}" \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  -H "Cookie: ${cookie_header}" \
  -X DELETE "${BASE_URL}/api/v1/auth/logout" | grep -q "200"

status_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  "${BASE_URL}/api/v1/auth/me")

if [ "${status_code}" != "401" ]; then
  echo "ERROR: Expected 401 after logout, got ${status_code}" >&2
  exit 1
fi
echo "OK: Logout invalidated session"

echo "==> All checks passed."
