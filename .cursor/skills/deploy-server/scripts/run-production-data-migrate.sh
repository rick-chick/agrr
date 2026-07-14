#!/usr/bin/env bash
# Production reference-data migration on live primary (Litestream → GCS), then Rust API.
#
# 1. Deploy migrate revision (--no-traffic)
# 2. Shift 100% traffic (stops Rails revision; single Litestream writer)
# 3. Wake instance → migrate → exec agrr-server
# 4. Redeploy normal entrypoint (start_agrr_server.sh)
#
#   .cursor/skills/deploy-server/scripts/run-production-data-migrate.sh
#   .cursor/skills/deploy-server/scripts/run-production-data-migrate.sh --skip-build
#
# Requires: .env.gcp (GCS_BUCKET=agrr-production-db, OAuth, etc.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_gcp-common.sh
source "${SCRIPT_DIR}/_gcp-common.sh"
_gcp_common_project_root "$SCRIPT_DIR" || exit 1
cd "$PROJECT_ROOT"

SKIP_BUILD=false
SKIP_MIGRATE=false
DRAIN_SECONDS="${DRAIN_SECONDS:-90}"
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    --skip-migrate) SKIP_MIGRATE=true ;;
    -h | --help)
      echo "Usage: $0 [--skip-build] [--skip-migrate]" >&2
      echo "  Env: DRAIN_SECONDS (default 90) after traffic cut" >&2
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
MIGRATE_IMAGE="${REGISTRY}/${PROJECT_ID}/agrr/${RUST_IMAGE_NAME}:latest"
CLOUD_RUN_SA="${CLOUD_RUN_SA:-cloud-run-agrr@${PROJECT_ID}.iam.gserviceaccount.com}"
GCS_BUCKET="${GCS_BUCKET:-agrr-production-db}"

if [ -z "$GCS_BUCKET" ]; then
  echo "ERROR: GCS_BUCKET is not set (.env.gcp)" >&2
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
  docker tag "${IMAGE}" "${MIGRATE_IMAGE}"
  _gcp_configure_docker_registry "$REGION"
  docker push "${IMAGE}"
  docker push "${MIGRATE_IMAGE}"
else
  echo "==> Using existing image ${MIGRATE_IMAGE}"
fi

deploy_rust_final() {
  echo "==> Deploy normal Rust entrypoint (start_agrr_server.sh, traffic to latest)"
  gcloud run deploy "${SERVICE}" \
    --image "${MIGRATE_IMAGE}" \
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
    --env-vars-file "$env_file" \
    --set-secrets "SCHEDULER_AUTH_TOKEN=scheduler-auth-token:latest" \
    --command /app/scripts/start_agrr_server.sh \
    --args=
}

if [ "$SKIP_MIGRATE" = true ]; then
  echo "==> --skip-migrate: verifying GCS replica then deploying Rust only"
  GCS_BUCKET="${GCS_BUCKET}" "${PROJECT_ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh" \
    "SELECT 1 FROM sqlite_master WHERE type='table' AND name='data_migration_history';
     SELECT COUNT(*) FROM data_migration_history WHERE version IN ('20260531120000','20260531130100','20251018075149');" \
    | tee /tmp/skip-migrate-check.txt
  for v in 20260531120000 20260531130100 20251018075149; do
    if ! grep -q "$v" /tmp/skip-migrate-check.txt; then
      echo "ERROR: GCS replica missing data_migration_history version ${v}" >&2
      exit 1
    fi
  done
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
    [ -n "${AGRR_BACKDOOR_TOKEN:-}" ] && _gcp_yaml_kv AGRR_BACKDOOR_TOKEN "${AGRR_BACKDOOR_TOKEN}"
    [ -n "${GCS_WEATHER_DATA_BUCKET:-}" ] && _gcp_yaml_kv GCS_WEATHER_DATA_BUCKET "${GCS_WEATHER_DATA_BUCKET}"
  } >"$env_file"
  deploy_rust_final
  SERVICE_URL="$(gcloud run services describe "${SERVICE}" \
    --region "${REGION}" --project "${PROJECT_ID}" \
    --format='value(status.url)')"
  echo "==> Rust health ${SERVICE_URL}/up"
  for i in $(seq 1 20); do
    body="$(curl -sf "${SERVICE_URL}/up" 2>/dev/null || true)"
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
  GCS_BUCKET="${GCS_BUCKET}" "${PROJECT_ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh" \
    "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('refinery_schema_history','data_migration_history');
     SELECT version, region, kind FROM data_migration_history WHERE version LIKE '20260531%' OR version='20251018075149';
     SELECT 'us', COUNT(*) FROM crops c WHERE c.region='us' AND c.is_reference=1 AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id=c.id);
     SELECT 'in', COUNT(*) FROM crops c WHERE c.region='in' AND c.is_reference=1 AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id=c.id);"
  TRAFFIC_REV="$(gcloud run services describe "${SERVICE}" --region "${REGION}" --project "${PROJECT_ID}" --format='value(status.traffic[0].revisionName)')"
  echo "==> Traffic revision: ${TRAFFIC_REV}"
  echo "==> Done: ${SERVICE} is Rust (agrr-server). LB cutover to rust-backend if not already done."
  exit 0
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
  [ -n "${AGRR_BACKDOOR_TOKEN:-}" ] && _gcp_yaml_kv AGRR_BACKDOOR_TOKEN "${AGRR_BACKDOOR_TOKEN}"
  [ -n "${GCS_WEATHER_DATA_BUCKET:-}" ] && _gcp_yaml_kv GCS_WEATHER_DATA_BUCKET "${GCS_WEATHER_DATA_BUCKET}"
} >"$env_file"

echo "==> Deploy migrate revision (--no-traffic): ${SERVICE}"
gcloud run deploy "${SERVICE}" \
  --image "${MIGRATE_IMAGE}" \
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
  --command /app/scripts/production-data-migrate-inner.sh

MIGRATE_REV="$(gcloud run services describe "${SERVICE}" \
  --region "${REGION}" --project "${PROJECT_ID}" \
  --format='value(status.latestCreatedRevisionName)')"
echo "==> Migrate revision: ${MIGRATE_REV}"

echo "==> Cut traffic: 100% → ${MIGRATE_REV} (0% on ${PREV_REVISION})"
gcloud run services update-traffic "${SERVICE}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --to-revisions="${MIGRATE_REV}=100"

echo "==> Drain old instances (${DRAIN_SECONDS}s)"
sleep "${DRAIN_SECONDS}"

SERVICE_URL="$(gcloud run services describe "${SERVICE}" \
  --region "${REGION}" --project "${PROJECT_ID}" \
  --format='value(status.url)')"
echo "==> Wake migrate instance: ${SERVICE_URL}/up"
for _ in $(seq 1 60); do
  if curl -sf "${SERVICE_URL}/up" >/dev/null 2>&1; then
    echo "==> Instance responding"
    break
  fi
  sleep 5
done

echo "==> Waiting for PRODUCTION_DATA_MIGRATE_COMPLETE (up to 45m)"
deadline=$((SECONDS + 2700))
found=0
while [ "$SECONDS" -lt "$deadline" ]; do
  if gcloud logging read \
    "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND resource.labels.revision_name=${MIGRATE_REV} AND textPayload:PRODUCTION_DATA_MIGRATE_COMPLETE" \
    --project "${PROJECT_ID}" --limit 1 --format='value(textPayload)' 2>/dev/null \
    | grep -q PRODUCTION_DATA_MIGRATE_COMPLETE; then
    found=1
    break
  fi
  sleep 30
done
if [ "$found" -ne 1 ]; then
  echo "ERROR: migration completion marker not seen on ${MIGRATE_REV}" >&2
  exit 1
fi

gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND resource.labels.revision_name=${MIGRATE_REV}" \
  --project "${PROJECT_ID}" --limit 40 --format='value(textPayload)' 2>/dev/null \
  | grep -E 'repair|data apply|schema stamp|without_stages|PRODUCTION_DATA_MIGRATE|ERROR|error' || true

deploy_rust_final

echo "==> Rust health ${SERVICE_URL}/up"
for i in $(seq 1 20); do
  body="$(curl -sf "${SERVICE_URL}/up" 2>/dev/null || true)"
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

echo "==> Verify Litestream replica"
GCS_BUCKET="${GCS_BUCKET}" "${PROJECT_ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh" \
  "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('refinery_schema_history','data_migration_history');
   SELECT version, region, kind FROM data_migration_history WHERE version LIKE '20260531%' OR version='20251018075149';
   SELECT 'us', COUNT(*) FROM crops c WHERE c.region='us' AND c.is_reference=1 AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id=c.id);
   SELECT 'in', COUNT(*) FROM crops c WHERE c.region='in' AND c.is_reference=1 AND NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id=c.id);"

echo "==> Done: ${SERVICE} is Rust (agrr-server). LB cutover to rust-backend if not already done."
