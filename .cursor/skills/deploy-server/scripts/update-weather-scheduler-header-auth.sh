#!/usr/bin/env bash
# Update Cloud Scheduler weather job to authenticate via X-Scheduler-Token header
# (query ?token= is rejected by agrr-server).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_gcp-common.sh
source "${SCRIPT_DIR}/_gcp-common.sh"
_gcp_common_project_root "$SCRIPT_DIR" || exit 1
cd "$PROJECT_ROOT"

_gcp_load_env_file "${PROJECT_ROOT}/.env.gcp"

PROJECT_ID="${PROJECT_ID:-agrr-475323}"
REGION="${REGION:-asia-northeast1}"
JOB_NAME="${WEATHER_SCHEDULER_JOB_NAME:-trigger-weather-update}"
TARGET_URL="${WEATHER_SCHEDULER_TARGET_URL:-https://agrr.net/api/v1/internal/jobs/trigger_weather_update}"
SECRET_NAME="${SCHEDULER_AUTH_TOKEN_SECRET:-scheduler-auth-token}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud not found" >&2
  exit 1
fi

if [ -z "${SCHEDULER_AUTH_TOKEN:-}" ]; then
  echo "==> Reading SCHEDULER_AUTH_TOKEN from Secret Manager (${SECRET_NAME})"
  SCHEDULER_AUTH_TOKEN="$(gcloud secrets versions access latest \
    --secret="$SECRET_NAME" \
    --project="$PROJECT_ID")"
fi

if [ -z "$SCHEDULER_AUTH_TOKEN" ]; then
  echo "ERROR: SCHEDULER_AUTH_TOKEN is empty" >&2
  exit 1
fi

echo "==> Updating scheduler job: $JOB_NAME ($REGION)"
echo "    URI: $TARGET_URL"
echo "    Auth: X-Scheduler-Token header (no query token)"

gcloud scheduler jobs update http "$JOB_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --uri="$TARGET_URL" \
  --http-method=POST \
  --update-headers="X-Scheduler-Token=${SCHEDULER_AUTH_TOKEN}"

echo "==> Scheduler job updated."
