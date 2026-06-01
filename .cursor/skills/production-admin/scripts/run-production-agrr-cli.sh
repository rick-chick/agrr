#!/usr/bin/env bash
# Run lib/core/agrr CLI on production Cloud Run via a one-off Job (same image as agrr-production).
# Does not touch live service traffic. Starts agrr daemon inside the job (required on production image).
#
# Usage (repo root):
#   .cursor/skills/production-admin/scripts/run-production-agrr-cli.sh weather \
#     --location 23.2599,77.4126 --start-date 2025-10-16 --end-date 2026-05-30 --data-source nasa-power
#   .cursor/skills/production-admin/scripts/run-production-agrr-cli.sh weather --preset bhopal-gap
#   .cursor/skills/production-admin/scripts/run-production-agrr-cli.sh logs
#   .cursor/skills/production-admin/scripts/run-production-agrr-cli.sh delete-job
#
# Requires: gcloud, .env.gcp (PROJECT_ID, REGION). Optional: SERVICE_NAME (default agrr-production).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../deploy-server/scripts" && pwd)"
# shellcheck source=../../deploy-server/scripts/_gcp-common.sh
source "${DEPLOY_SCRIPTS_DIR}/_gcp-common.sh"
_gcp_common_project_root "$SCRIPT_DIR" || exit 1
cd "$PROJECT_ROOT"

_gcp_load_env_file "${PROJECT_ROOT}/.env.gcp"

PROJECT_ID="${PROJECT_ID:-agrr-475323}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE_NAME:-agrr-production}"
JOB="${AGRR_PROD_CLI_JOB_NAME:-agrr-prod-agrr-cli-spike}"
SA="${CLOUD_RUN_SA:-cloud-run-agrr@${PROJECT_ID}.iam.gserviceaccount.com}"
POLL_INTERVAL_SEC="${POLL_INTERVAL_SEC:-5}"
POLL_MAX_ATTEMPTS="${POLL_MAX_ATTEMPTS:-120}"
LAST_EXEC_FILE="${TMPDIR:-/tmp}/agrr-prod-cli-last-execution.txt"

info() { echo "run-production-agrr-cli: $*" >&2; }
fail() { echo "run-production-agrr-cli: ERROR: $*" >&2; exit 1; }

need_gcloud() {
  command -v gcloud >/dev/null 2>&1 || fail "gcloud not found"
}

production_image() {
  gcloud run services describe "$SERVICE" \
    --region "$REGION" --project "$PROJECT_ID" \
    --format='value(spec.template.spec.containers[0].image)'
}

save_execution() {
  printf '%s\n' "$1" >"$LAST_EXEC_FILE"
}

last_execution() {
  if [[ -f "$LAST_EXEC_FILE" ]]; then
    tr -d '\n' <"$LAST_EXEC_FILE"
    return 0
  fi
  gcloud run jobs executions list --job="$JOB" \
    --region="$REGION" --project="$PROJECT_ID" \
    --limit=1 --format='value(name)' 2>/dev/null || true
}

fetch_logs() {
  local exec_name="${1:-$(last_execution)}"
  [[ -n "$exec_name" ]] || fail "no execution name (run weather first or pass EXECUTION)"
  gcloud logging read \
    "resource.type=\"cloud_run_job\" AND labels.\"run.googleapis.com/execution_name\"=\"${exec_name}\"" \
    --project="$PROJECT_ID" --limit=80 \
    --format='value(timestamp,textPayload)' 2>/dev/null | tac
}

delete_job() {
  need_gcloud
  gcloud run jobs delete "$JOB" --region="$REGION" --project="$PROJECT_ID" --quiet 2>/dev/null \
    && info "deleted job $JOB" \
    || info "job $JOB not found (already deleted)"
}

deploy_and_run_weather() {
  local location="$1" start_date="$2" end_date="$3" data_source="$4"

  need_gcloud
  local image
  image="$(production_image)" || fail "could not resolve image for service $SERVICE"
  info "service=$SERVICE image=$image"
  info "weather location=$location start=$start_date end=$end_date source=$data_source"

  # Inner script: production agrr requires daemon; image has no /usr/bin/time.
  gcloud run jobs deploy "$JOB" \
    --image="$image" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --service-account="$SA" \
    --cpu=2 \
    --memory=2Gi \
    --task-timeout=600 \
    --max-retries=0 \
    --set-env-vars="WEATHER_LOCATION=${location},WEATHER_START=${start_date},WEATHER_END=${end_date},WEATHER_DATA_SOURCE=${data_source}" \
    --command=/bin/bash \
    --args=-c,'set -euo pipefail
AGRR=/usr/local/bin/agrr
SOCKET=/tmp/agrr.sock
export AGRR_SOCKET_PATH="$SOCKET"
echo "=== agrr production CLI spike (weather) ==="
echo "location=${WEATHER_LOCATION} start=${WEATHER_START} end=${WEATHER_END} source=${WEATHER_DATA_SOURCE}"
"$AGRR" daemon start
for i in $(seq 1 90); do
  [[ -S "$SOCKET" ]] && { echo "daemon ready after ${i}s"; break; }
  sleep 1
done
[[ -S "$SOCKET" ]] || { echo "ERROR: daemon socket not created"; exit 1; }
OUT=/tmp/weather_out.json
START_TS=$(date +%s)
"$AGRR" weather \
  --location "${WEATHER_LOCATION}" \
  --start-date "${WEATHER_START}" \
  --end-date "${WEATHER_END}" \
  --data-source "${WEATHER_DATA_SOURCE}" \
  --json \
  --output "$OUT"
END_TS=$(date +%s)
echo "elapsed_sec=$((END_TS - START_TS))"
python3 -c "
import json, os
p=\"/tmp/weather_out.json\"
with open(p) as f:
    d=json.load(f)
data=d.get(\"data\") or []
print(\"records\", len(data))
if data:
    print(\"first\", data[0].get(\"time\"))
    print(\"last\", data[-1].get(\"time\"))
print(\"output_bytes\", os.path.getsize(p))
"
"$AGRR" daemon stop 2>/dev/null || true
echo "=== done ==="
'

  local exec_name
  exec_name="$(gcloud run jobs execute "$JOB" \
    --region="$REGION" --project="$PROJECT_ID" \
    --format='value(metadata.name)')"
  save_execution "$exec_name"
  info "execution=$exec_name"
  info "console: https://console.cloud.google.com/run/jobs/executions/details/${REGION}/${exec_name}?project=${PROJECT_ID}"

  local i succeeded failed
  for i in $(seq 1 "$POLL_MAX_ATTEMPTS"); do
    succeeded="$(gcloud run jobs executions describe "$exec_name" \
      --region="$REGION" --project="$PROJECT_ID" \
      --format='value(status.succeededCount)' 2>/dev/null || echo "")"
    failed="$(gcloud run jobs executions describe "$exec_name" \
      --region="$REGION" --project="$PROJECT_ID" \
      --format='value(status.failedCount)' 2>/dev/null || echo "")"
    if [[ "$succeeded" == "1" ]]; then
      info "completed successfully"
      fetch_logs "$exec_name"
      return 0
    fi
    if [[ "$failed" == "1" ]]; then
      fail "execution failed — logs:\n$(fetch_logs "$exec_name")"
    fi
    sleep "$POLL_INTERVAL_SEC"
  done
  fail "timed out waiting for execution $exec_name (see logs subcommand)"
}

apply_preset() {
  local preset="$1"
  case "$preset" in
    bhopal-gap)
      LOCATION="23.2599,77.4126"
      START_DATE="2025-10-16"
      END_DATE="2026-05-30"
      DATA_SOURCE="nasa-power"
      ;;
    bhopal-chain-window)
      # OptimizationJobChainWeatherComputation window for latest=2025-10-15, today≈2026-06-02
      LOCATION="23.2599,77.4126"
      START_DATE="2006-06-01"
      END_DATE="2026-05-30"
      DATA_SOURCE="nasa-power"
      ;;
    delhi-sample)
      LOCATION="28.5844,77.2031"
      START_DATE="2024-06-01"
      END_DATE="2024-06-05"
      DATA_SOURCE="nasa-power"
      ;;
    *)
      fail "unknown preset: $preset (bhopal-gap | bhopal-chain-window | delhi-sample)"
      ;;
  esac
}

cmd_weather() {
  local location="" start_date="" end_date="" data_source="nasa-power" preset=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --location) location="$2"; shift 2 ;;
      --start-date) start_date="$2"; shift 2 ;;
      --end-date) end_date="$2"; shift 2 ;;
      --data-source) data_source="$2"; shift 2 ;;
      --preset) preset="$2"; shift 2 ;;
      -h | --help)
        sed -n '1,20p' "$0"
        echo "  --preset bhopal-gap | bhopal-chain-window | delhi-sample"
        exit 0
        ;;
      *) fail "unknown option: $1" ;;
    esac
  done

  if [[ -n "$preset" ]]; then
    apply_preset "$preset"
    location="${LOCATION}"
    start_date="${START_DATE}"
    end_date="${END_DATE}"
    data_source="${DATA_SOURCE}"
  fi

  [[ -n "$location" && -n "$start_date" && -n "$end_date" ]] \
    || fail "require --location, --start-date, --end-date (or --preset)"

  deploy_and_run_weather "$location" "$start_date" "$end_date" "$data_source"
}

usage() {
  cat <<EOF
Usage:
  $0 weather [--location LAT,LON --start-date YYYY-MM-DD --end-date YYYY-MM-DD] [--data-source SRC] [--preset NAME]
  $0 logs [EXECUTION_NAME]
  $0 delete-job

Env: PROJECT_ID, REGION, SERVICE_NAME (agrr-production), AGRR_PROD_CLI_JOB_NAME (agrr-prod-agrr-cli-spike)
EOF
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    weather) cmd_weather "$@" ;;
    logs) fetch_logs "${1:-}" ;;
    delete-job) delete_job ;;
    -h | --help | "") usage ;;
    *) fail "unknown command: $cmd (weather | logs | delete-job)" ;;
  esac
}

main "$@"
