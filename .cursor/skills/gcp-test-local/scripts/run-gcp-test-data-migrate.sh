#!/usr/bin/env bash
# One-shot GCP test reference-data repair: bootstrap DB, apply in repair migrations, then agrr-server.
# Restores default image CMD on success (second deploy).
#
#   .cursor/skills/gcp-test-local/scripts/run-gcp-test-data-migrate.sh
#   .cursor/skills/gcp-test-local/scripts/run-gcp-test-data-migrate.sh --skip-build
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

SKIP_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --skip-build) SKIP_BUILD=true ;;
    -h | --help)
      echo "Usage: $0 [--skip-build]" >&2
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

load_env() {
  local f=$1
  if [ -f "$f" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$f"
    set +a
  fi
}

load_env "${PROJECT_ROOT}/.env.gcp"
load_env "${PROJECT_ROOT}/.env.gcp.test"

PROJECT_ID="${PROJECT_ID:-agrr-475323}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE_NAME:-agrr-test}"
IMAGE_NAME="${IMAGE_NAME:-agrr-test}"
IMAGE="${REGISTRY:-asia-northeast1-docker.pkg.dev}/${PROJECT_ID}/agrr/${IMAGE_NAME}:latest"
CLOUD_RUN_SA="${CLOUD_RUN_SA:-cloud-run-agrr@${PROJECT_ID}.iam.gserviceaccount.com}"
GCS_BUCKET="${GCS_BUCKET:-agrr-test-db}"

if [ -z "$GCS_BUCKET" ]; then
  echo "ERROR: GCS_BUCKET is not set (.env.gcp.test)" >&2
  exit 1
fi

if [ "$SKIP_BUILD" = false ]; then
  echo "==> Building ${IMAGE}"
  docker build -f Dockerfile.agrr-server -t "${IMAGE}" .
  echo "==> Pushing image"
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  docker push "${IMAGE}"
fi

env_file="$(mktemp)"
trap 'rm -f "$env_file"' EXIT
yaml_kv() {
  local key=$1 val=${2:-}
  printf '%s: "%s"\n' "$key" "$(printf '%s' "$val" | sed 's/"/\\"/g')"
}
{
  yaml_kv AGRR_ENV production
  yaml_kv AGRR_APP_ROOT /app
  yaml_kv AGRR_SQLITE_PATH /tmp/production.sqlite3
  yaml_kv AGRR_CACHE_SQLITE_PATH /tmp/production_cache.sqlite3
  yaml_kv GCS_BUCKET "${GCS_BUCKET}"
  yaml_kv WEATHER_DATA_STORAGE "${WEATHER_DATA_STORAGE:-gcs}"
  yaml_kv USE_AGRR_DAEMON "${USE_AGRR_DAEMON:-true}"
  yaml_kv ALLOWED_HOSTS "${ALLOWED_HOSTS:-}"
  yaml_kv GOOGLE_CLIENT_ID "${GOOGLE_CLIENT_ID:-}"
  yaml_kv GOOGLE_CLIENT_SECRET "${GOOGLE_CLIENT_SECRET:-}"
  yaml_kv SCHEDULER_AUTH_TOKEN "${SCHEDULER_AUTH_TOKEN:-}"
  yaml_kv AGRR_BACKDOOR_TOKEN "${AGRR_BACKDOOR_TOKEN:-}"
  yaml_kv FRONTEND_URL "${FRONTEND_URL:-}"
  yaml_kv GOOGLE_OAUTH_REDIRECT_URI "${GOOGLE_OAUTH_REDIRECT_URI:-}"
  yaml_kv RAILS_MASTER_KEY "${RAILS_MASTER_KEY:-}"
  yaml_kv SECRET_KEY_BASE "${SECRET_KEY_BASE:-}"
  [ -n "${GCS_WEATHER_DATA_BUCKET:-}" ] && yaml_kv GCS_WEATHER_DATA_BUCKET "${GCS_WEATHER_DATA_BUCKET}"
} >"$env_file"

MIGRATE_AND_SERVE='set -euo pipefail
export AGRR_APP_ROOT=/app AGRR_SQLITE_PATH=/tmp/production.sqlite3 AGRR_CACHE_SQLITE_PATH=/tmp/production_cache.sqlite3 SKIP_CABLE_DB=true
SCRIPT_DIR=/app/scripts
source "${SCRIPT_DIR}/db_bootstrap_common.sh"
run_db_bootstrap
"${SCRIPT_DIR}/run-agrr-migrate.sh" data apply --region in --kind repair
echo "Waiting for Litestream to replicate primary DB to GCS (180s)..."
sleep 180
exec agrr-server'

echo "==> Deploy ${SERVICE}: bootstrap + data apply (in repair) + agrr-server"
gcloud run deploy "${SERVICE}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --project "${PROJECT_ID}" \
  --service-account "${CLOUD_RUN_SA}" \
  --allow-unauthenticated \
  --port 8080 \
  --cpu 2 \
  --memory 4Gi \
  --timeout 3600 \
  --max-instances 1 \
  --env-vars-file "$env_file" \
  --command /bin/bash \
  --args=-ec,"${MIGRATE_AND_SERVE}"

SERVICE_URL="$(gcloud run services describe "${SERVICE}" --region "${REGION}" --project "${PROJECT_ID}" --format='value(status.url)')"
echo "==> Waiting for ${SERVICE_URL}/up"
for _ in $(seq 1 120); do
  if curl -sf "${SERVICE_URL}/up" >/dev/null 2>&1; then
    echo "==> Service is up"
    break
  fi
  sleep 5
done

echo "==> Recent logs (repair apply)"
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE}" \
  --project "${PROJECT_ID}" --limit 40 --format='value(textPayload)' 2>/dev/null | grep -E 'repair|apply|data apply|error|ERROR' || true

echo "==> Restore default entrypoint (start_agrr_server.sh)"
gcloud run deploy "${SERVICE}" \
  --image "${IMAGE}" \
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
  --command /app/scripts/start_agrr_server.sh \
  --args=

echo "==> Verify Litestream replica (in reference crops without stages)"
GCS_BUCKET="${GCS_BUCKET}" "${PROJECT_ROOT}/.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh" \
  "SELECT version, region, kind FROM data_migration_history WHERE version LIKE '20260531%';
   SELECT SUM(CASE WHEN NOT EXISTS (SELECT 1 FROM crop_stages cs WHERE cs.crop_id = crops.id) THEN 1 ELSE 0 END) AS without_stages, COUNT(*) AS total FROM crops WHERE is_reference=1 AND region='in';"

echo "==> Done: ${SERVICE_URL}"
