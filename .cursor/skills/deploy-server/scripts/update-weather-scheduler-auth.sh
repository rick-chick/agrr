#!/bin/bash
# Update Cloud Scheduler weather job to authenticate via X-Scheduler-Token header only.
# Query-string ?token= is rejected by agrr-server (issue #1209).

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
SCHEDULER_URI="${WEATHER_SCHEDULER_URI:-https://agrr.net/api/v1/internal/jobs/trigger_weather_update}"
SECRET_NAME="${SCHEDULER_AUTH_SECRET_NAME:-scheduler-auth-token}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud not found" >&2
  exit 1
fi

echo "==> Reading scheduler auth token from Secret Manager (${SECRET_NAME})"
TOKEN="$(gcloud secrets versions access latest \
  --secret="${SECRET_NAME}" \
  --project="${PROJECT_ID}")"

if [ -z "${TOKEN}" ]; then
  echo "ERROR: scheduler auth token is empty" >&2
  exit 1
fi

echo "==> Updating Cloud Scheduler job '${JOB_NAME}' (${REGION})"
echo "    URI: ${SCHEDULER_URI}"
echo "    Auth: X-Scheduler-Token header (query token removed)"

gcloud scheduler jobs update http "${JOB_NAME}" \
  --location="${REGION}" \
  --project="${PROJECT_ID}" \
  --uri="${SCHEDULER_URI}" \
  --http-method=POST \
  --update-headers="X-Scheduler-Token=${TOKEN}" \
  --clear-query-params

echo "==> Scheduler job updated. Verify with:"
echo "    gcloud scheduler jobs describe ${JOB_NAME} --location=${REGION} --project=${PROJECT_ID}"
