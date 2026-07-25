#!/usr/bin/env bash
# Emergency restore of production primary SQLite from a pinned Litestream generation.
#
#   .cursor/skills/deploy-server/scripts/run-production-primary-restore.sh
#   .cursor/skills/deploy-server/scripts/run-production-primary-restore.sh --skip-build
#   LITESTREAM_RESTORE_GENERATION=9922dd4be4b68775 MIN_RESTORED_USERS=30 ...
#
# Flow:
#   1. Deploy restore revision (--no-traffic)
#   2. Shift 100% traffic (single Litestream writer)
#   3. Wait for PRODUCTION_PRIMARY_RESTORE_COMPLETE
#   4. Redeploy normal entrypoint (start_agrr_server.sh with synchronous bootstrap)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_gcp-common.sh
source "${SCRIPT_DIR}/_gcp-common.sh"
_gcp_common_project_root "$SCRIPT_DIR" || exit 1
cd "$PROJECT_ROOT"

SKIP_BUILD=false
DRAIN_SECONDS="${DRAIN_SECONDS:-90}"
LITESTREAM_RESTORE_GENERATION="${LITESTREAM_RESTORE_GENERATION:-9922dd4be4b68775}"
MIN_RESTORED_USERS="${MIN_RESTORED_USERS:-30}"
LITESTREAM_REPLICATE_WAIT_SECONDS="${LITESTREAM_REPLICATE_WAIT_SECONDS:-180}"

for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    -h | --help)
      echo "Usage: $0 [--skip-build]" >&2
      echo "  Env: LITESTREAM_RESTORE_GENERATION (default 9922dd4be4b68775)" >&2
      echo "       MIN_RESTORED_USERS (default 30)" >&2
      echo "       DRAIN_SECONDS (default 90)" >&2
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

_gcp_load_env_file "${PROJECT_ROOT}/.env.gcp"
FRONTEND_URL="${FRONTEND_URL:-https://agrr.net}"
GOOGLE_OAUTH_REDIRECT_URI="${GOOGLE_OAUTH_REDIRECT_URI:-https://agrr.net/auth/google_oauth2/callback}"

PROJECT_ID="${PROJECT_ID:-agrr-475323}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE_NAME:-agrr-production}"
RUST_IMAGE_NAME="${RUST_IMAGE_NAME:-agrr-server}"
REGISTRY="${REGISTRY:-asia-northeast1-docker.pkg.dev}"
RESTORE_IMAGE="${REGISTRY}/${PROJECT_ID}/agrr/${RUST_IMAGE_NAME}:latest"
CLOUD_RUN_SA="${CLOUD_RUN_SA:-cloud-run-agrr@${PROJECT_ID}.iam.gserviceaccount.com}"
GCS_BUCKET="${GCS_BUCKET:-agrr-production-db}"

if [ -z "$GCS_BUCKET" ]; then
  echo "ERROR: GCS_BUCKET is not set (.env.gcp)" >&2
  exit 1
fi

echo "==> Pre-check: pinned generation has >= ${MIN_RESTORED_USERS} users"
PRE_COUNT="$(
  GCS_BUCKET="${GCS_BUCKET}" LITESTREAM_RESTORE_GENERATION="${LITESTREAM_RESTORE_GENERATION}" \
    "${PROJECT_ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh" \
    "SELECT COUNT(*) FROM users;" | tail -1 | tr -d '[:space:]'
)"
echo "Pinned generation user count: ${PRE_COUNT}"
if [ "${PRE_COUNT}" -lt "${MIN_RESTORED_USERS}" ]; then
  echo "ERROR: generation ${LITESTREAM_RESTORE_GENERATION} has ${PRE_COUNT} users (need >= ${MIN_RESTORED_USERS})" >&2
  exit 1
fi

PREV_REVISION="$(gcloud run services describe "${SERVICE}" \
  --region "${REGION}" --project "${PROJECT_ID}" \
  --format='value(status.traffic[0].revisionName)')"
echo "==> Current traffic revision: ${PREV_REVISION}"

if [ "$SKIP_BUILD" = false ]; then
  DEPLOY_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  IMAGE="${REGISTRY}/${PROJECT_ID}/agrr/${RUST_IMAGE_NAME}:${DEPLOY_TIMESTAMP}"
  echo "==> Building ${IMAGE}"
  docker build -f Dockerfile.agrr-server -t "${IMAGE}" .
  docker tag "${IMAGE}" "${RESTORE_IMAGE}"
  _gcp_configure_docker_registry "$REGION"
  docker push "${IMAGE}"
  docker push "${RESTORE_IMAGE}"
else
  echo "==> Using existing image ${RESTORE_IMAGE}"
fi

env_file="$(mktemp)"
trap 'rm -f "$env_file"' EXIT
{
  _gcp_yaml_kv AGRR_ENV production
  _gcp_yaml_kv AGRR_APP_ROOT /app
  _gcp_yaml_kv AGRR_SQLITE_PATH /tmp/production.sqlite3
  _gcp_yaml_kv AGRR_CACHE_SQLITE_PATH /tmp/production_cache.sqlite3
  _gcp_yaml_kv GCS_BUCKET "${GCS_BUCKET}"
  _gcp_yaml_kv WEATHER_DATA_STORAGE "${WEATHER_DATA_STORAGE:-gcs}"
  _gcp_yaml_kv USE_AGRR_DAEMON "${USE_AGRR_DAEMON:-true}"
  _gcp_yaml_kv ALLOWED_HOSTS "${ALLOWED_HOSTS:-}"
  _gcp_yaml_kv GOOGLE_CLIENT_ID "${GOOGLE_CLIENT_ID:-}"
  _gcp_yaml_kv GOOGLE_CLIENT_SECRET "${GOOGLE_CLIENT_SECRET:-}"
  _gcp_yaml_kv FRONTEND_URL "${FRONTEND_URL}"
  _gcp_yaml_kv GOOGLE_OAUTH_REDIRECT_URI "${GOOGLE_OAUTH_REDIRECT_URI}"
  _gcp_yaml_kv SQLITE_BUSY_TIMEOUT_MS "${SQLITE_BUSY_TIMEOUT_MS:-60000}"
  _gcp_yaml_kv LITESTREAM_RESTORE_GENERATION "${LITESTREAM_RESTORE_GENERATION}"
  _gcp_yaml_kv MIN_RESTORED_USERS "${MIN_RESTORED_USERS}"
  _gcp_yaml_kv LITESTREAM_REPLICATE_WAIT_SECONDS "${LITESTREAM_REPLICATE_WAIT_SECONDS}"
  [ -n "${AGRR_BACKDOOR_TOKEN:-}" ] && _gcp_yaml_kv AGRR_BACKDOOR_TOKEN "${AGRR_BACKDOOR_TOKEN}"
  [ -n "${GCS_WEATHER_DATA_BUCKET:-}" ] && _gcp_yaml_kv GCS_WEATHER_DATA_BUCKET "${GCS_WEATHER_DATA_BUCKET}"
} >"$env_file"

deploy_normal() {
  local normal_env_file
  normal_env_file="$(mktemp)"
  {
    _gcp_yaml_kv AGRR_ENV production
    _gcp_yaml_kv AGRR_APP_ROOT /app
    _gcp_yaml_kv AGRR_SQLITE_PATH /tmp/production.sqlite3
    _gcp_yaml_kv AGRR_CACHE_SQLITE_PATH /tmp/production_cache.sqlite3
    _gcp_yaml_kv GCS_BUCKET "${GCS_BUCKET}"
    _gcp_yaml_kv WEATHER_DATA_STORAGE "${WEATHER_DATA_STORAGE:-gcs}"
    _gcp_yaml_kv USE_AGRR_DAEMON "${USE_AGRR_DAEMON:-true}"
    _gcp_yaml_kv ALLOWED_HOSTS "${ALLOWED_HOSTS:-}"
    _gcp_yaml_kv GOOGLE_CLIENT_ID "${GOOGLE_CLIENT_ID:-}"
    _gcp_yaml_kv GOOGLE_CLIENT_SECRET "${GOOGLE_CLIENT_SECRET:-}"
    _gcp_yaml_kv FRONTEND_URL "${FRONTEND_URL}"
    _gcp_yaml_kv GOOGLE_OAUTH_REDIRECT_URI "${GOOGLE_OAUTH_REDIRECT_URI}"
    _gcp_yaml_kv SQLITE_BUSY_TIMEOUT_MS "${SQLITE_BUSY_TIMEOUT_MS:-60000}"
    [ -n "${AGRR_BACKDOOR_TOKEN:-}" ] && _gcp_yaml_kv AGRR_BACKDOOR_TOKEN "${AGRR_BACKDOOR_TOKEN}"
    [ -n "${GCS_WEATHER_DATA_BUCKET:-}" ] && _gcp_yaml_kv GCS_WEATHER_DATA_BUCKET "${GCS_WEATHER_DATA_BUCKET}"
  } >"$normal_env_file"

  echo "==> Deploy normal Rust entrypoint (start_agrr_server.sh)"
  gcloud run deploy "${SERVICE}" \
    --image "${RESTORE_IMAGE}" \
    --region "${REGION}" \
    --platform managed \
    --project "${PROJECT_ID}" \
    --service-account "${CLOUD_RUN_SA}" \
    --allow-unauthenticated \
    --port 8080 \
    --cpu 2 \
    --memory 2Gi \
    --timeout 600 \
    --max-instances 1 \
    --min-instances 0 \
    --startup-probe=initialDelaySeconds=15,timeoutSeconds=5,periodSeconds=5,failureThreshold=24,httpGet.path=/up,httpGet.port=8080 \
    --env-vars-file "$normal_env_file" \
    --set-secrets "SCHEDULER_AUTH_TOKEN=scheduler-auth-token:latest" \
    --command /app/scripts/start_agrr_server.sh \
    --args=
  rm -f "$normal_env_file"
}

echo "==> Deploy restore revision (--no-traffic)"
gcloud run deploy "${SERVICE}" \
  --image "${RESTORE_IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --project "${PROJECT_ID}" \
  --service-account "${CLOUD_RUN_SA}" \
  --allow-unauthenticated \
  --no-traffic \
  --port 8080 \
  --cpu 2 \
  --memory 4Gi \
  --timeout 3600 \
  --max-instances 1 \
  --env-vars-file "$env_file" \
  --set-secrets "SCHEDULER_AUTH_TOKEN=scheduler-auth-token:latest" \
  --startup-probe=initialDelaySeconds=60,timeoutSeconds=10,periodSeconds=30,failureThreshold=90,httpGet.port=8080,httpGet.path=/up \
  --command /app/scripts/production-primary-restore-inner.sh

RESTORE_REV="$(gcloud run services describe "${SERVICE}" \
  --region "${REGION}" --project "${PROJECT_ID}" \
  --format='value(status.latestCreatedRevisionName)')"
echo "==> Restore revision: ${RESTORE_REV}"

echo "==> Cut traffic: 100% → ${RESTORE_REV}"
gcloud run services update-traffic "${SERVICE}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --to-revisions="${RESTORE_REV}=100"

echo "==> Drain old instances (${DRAIN_SECONDS}s)"
sleep "${DRAIN_SECONDS}"

SERVICE_URL="$(gcloud run services describe "${SERVICE}" \
  --region "${REGION}" --project "${PROJECT_ID}" \
  --format='value(status.url)')"
echo "==> Wake restore instance: ${SERVICE_URL}/up"
for _ in $(seq 1 60); do
  if curl -sf "${SERVICE_URL}/up" >/dev/null 2>&1; then
    echo "==> Instance responding"
    break
  fi
  sleep 5
done

echo "==> Waiting for PRODUCTION_PRIMARY_RESTORE_COMPLETE (up to 45m)"
deadline=$((SECONDS + 2700))
found=0
while [ "$SECONDS" -lt "$deadline" ]; do
  if gcloud logging read \
    "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND resource.labels.revision_name=${RESTORE_REV} AND textPayload:PRODUCTION_PRIMARY_RESTORE_COMPLETE" \
    --project "${PROJECT_ID}" --limit 1 --format='value(textPayload)' 2>/dev/null \
    | grep -q PRODUCTION_PRIMARY_RESTORE_COMPLETE; then
    found=1
    break
  fi
  sleep 30
done
if [ "$found" -ne 1 ]; then
  echo "ERROR: restore completion marker not seen on ${RESTORE_REV}" >&2
  exit 1
fi

gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND resource.labels.revision_name=${RESTORE_REV}" \
  --project "${PROJECT_ID}" --limit 40 --format='value(textPayload)' 2>/dev/null \
  | grep -E 'PRODUCTION_PRIMARY_RESTORE|restore|ERROR|generation|USER_COUNT' || true

echo "==> Verify GCS replica user count"
GCS_BUCKET="${GCS_BUCKET}" "${PROJECT_ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh" \
  "SELECT COUNT(*) AS users FROM users;"

deploy_normal

echo "==> Health check"
health_url="https://agrr.net/up"
for i in $(seq 1 20); do
  body="$(curl -sf "${health_url}" 2>/dev/null || true)"
  if [ "$body" = "ok" ]; then
    echo "✓ agrr-server health OK"
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "ERROR: expected body 'ok', got: ${body:-<empty>}" >&2
    exit 1
  fi
  sleep 15
done

echo "==> Done: production primary restored from generation ${LITESTREAM_RESTORE_GENERATION}"
