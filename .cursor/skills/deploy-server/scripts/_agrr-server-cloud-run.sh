# shellcheck shell=bash
# Build Dockerfile.agrr-server and deploy to Cloud Run (sourced by deploy scripts).

# Public URL for /up when ingress is load-balancer-only (*.run.app returns 404).
_agrr_server_production_health_url() {
  local base="${PRODUCTION_PUBLIC_URL:-}"
  if [ -z "$base" ]; then
    base="${FRONTEND_URL%%,*}"
  fi
  base="${base%/}"
  case "$base" in
    http://* | https://*) ;;
    *) base="https://${base}" ;;
  esac
  printf '%s/up' "$base"
}

_agrr_server_deploy() {
  local mode=$1 # test | production
  local _script_dir_unused=$2 # kept for call-site compatibility (gcp-test-local)

  local deploy_scripts_dir
  deploy_scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=_gcp-common.sh
  source "${deploy_scripts_dir}/_gcp-common.sh"
  _gcp_common_project_root "$deploy_scripts_dir" || return 1
  cd "$PROJECT_ROOT"

  if [ "$mode" = "test" ]; then
    _gcp_load_env_file "${PROJECT_ROOT}/.env.gcp"
    _gcp_load_env_file "${PROJECT_ROOT}/.env.gcp.test"
    FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:4201,http://localhost:4201}"
    if [ -z "${GOOGLE_OAUTH_REDIRECT_URI:-}" ]; then
      local fe_origin
      fe_origin="${FRONTEND_URL%%,*}"
      GOOGLE_OAUTH_REDIRECT_URI="${fe_origin%/}/auth/google_oauth2/callback"
    fi
    SKIP_GIT_CHECKS="${SKIP_GIT_CHECKS:-1}"
  else
    _gcp_load_env_file "${PROJECT_ROOT}/.env.gcp"
    FRONTEND_URL="${FRONTEND_URL:-https://agrr.net}"
    GOOGLE_OAUTH_REDIRECT_URI="${GOOGLE_OAUTH_REDIRECT_URI:-https://agrr.net/auth/google_oauth2/callback}"
    _gcp_preflight 1 || return 1
  fi

  PROJECT_ID="${PROJECT_ID:-agrr-475323}"
  REGION="${REGION:-asia-northeast1}"
  if [ "$mode" = "production" ]; then
    SERVICE="${SERVICE_NAME:-agrr-production}"
    IMAGE_NAME="${RUST_IMAGE_NAME:-agrr-server}"
    DEPLOY_TIMESTAMP="${DEPLOY_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
    IMAGE_TAG="${IMAGE_TAG:-$DEPLOY_TIMESTAMP}"
  else
    SERVICE="${SERVICE_NAME:-agrr-test}"
    IMAGE_NAME="${IMAGE_NAME:-agrr-test}"
    IMAGE_TAG="${IMAGE_TAG:-latest}"
  fi

  REGISTRY="${REGISTRY:-asia-northeast1-docker.pkg.dev}"
  IMAGE_BASE="${REGISTRY}/${PROJECT_ID}/agrr/${IMAGE_NAME}"
  IMAGE="${IMAGE_BASE}:${IMAGE_TAG}"
  WEATHER_DATA_STORAGE="${WEATHER_DATA_STORAGE:-gcs}"
  USE_AGRR_DAEMON="${USE_AGRR_DAEMON:-true}"
  CLOUD_RUN_SA="${CLOUD_RUN_SA:-cloud-run-agrr@${PROJECT_ID}.iam.gserviceaccount.com}"
  GCS_BUCKET="${GCS_BUCKET:-}"
  if [ -z "$GCS_BUCKET" ]; then
    echo "ERROR: GCS_BUCKET is required" >&2
    return 1
  fi

  if [ "$mode" = "test" ] && [ -n "$GCS_BUCKET" ]; then
    if ! gcloud storage buckets describe "gs://${GCS_BUCKET}" --project "$PROJECT_ID" >/dev/null 2>&1; then
      echo "==> Creating gs://${GCS_BUCKET}"
      gcloud storage buckets create "gs://${GCS_BUCKET}" \
        --project="$PROJECT_ID" --location="$REGION" --uniform-bucket-level-access
      gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET}" \
        --project="$PROJECT_ID" --member="serviceAccount:${CLOUD_RUN_SA}" \
        --role="roles/storage.objectAdmin" --quiet >/dev/null
    fi
  fi

  echo "==> Mode: $mode"
  echo "==> Service: $SERVICE"
  echo "==> Building ${IMAGE}"
  docker build -f Dockerfile.agrr-server -t "${IMAGE}" .
  if [ "$mode" = "production" ]; then
    docker tag "${IMAGE}" "${IMAGE_BASE}:latest"
  fi

  echo "==> Pushing image"
  _gcp_configure_docker_registry "$REGION"
  docker push "${IMAGE}"
  if [ "$mode" = "production" ]; then
    docker push "${IMAGE_BASE}:latest"
  fi

  local env_file
  env_file="$(mktemp)"
  trap 'rm -f "$env_file"' RETURN

  {
    _gcp_yaml_kv AGRR_ENV production
    _gcp_yaml_kv AGRR_APP_ROOT /app
    _gcp_yaml_kv AGRR_SQLITE_PATH /tmp/production.sqlite3
    _gcp_yaml_kv AGRR_CACHE_SQLITE_PATH /tmp/production_cache.sqlite3
    _gcp_yaml_kv GCS_BUCKET "${GCS_BUCKET}"
    _gcp_yaml_kv WEATHER_DATA_STORAGE "${WEATHER_DATA_STORAGE}"
    _gcp_yaml_kv USE_AGRR_DAEMON "${USE_AGRR_DAEMON}"
    _gcp_yaml_kv ALLOWED_HOSTS "${ALLOWED_HOSTS:-}"
    [ -n "${GOOGLE_CLIENT_ID:-}" ] && _gcp_yaml_kv GOOGLE_CLIENT_ID "${GOOGLE_CLIENT_ID}"
    [ -n "${GOOGLE_CLIENT_SECRET:-}" ] && _gcp_yaml_kv GOOGLE_CLIENT_SECRET "${GOOGLE_CLIENT_SECRET}"
    [ -n "${AGRR_BACKDOOR_TOKEN:-}" ] && _gcp_yaml_kv AGRR_BACKDOOR_TOKEN "${AGRR_BACKDOOR_TOKEN}"
    [ -n "${FRONTEND_URL:-}" ] && _gcp_yaml_kv FRONTEND_URL "${FRONTEND_URL}"
    [ -n "${GOOGLE_OAUTH_REDIRECT_URI:-}" ] && _gcp_yaml_kv GOOGLE_OAUTH_REDIRECT_URI "${GOOGLE_OAUTH_REDIRECT_URI}"
    _gcp_yaml_kv SQLITE_BUSY_TIMEOUT_MS "${SQLITE_BUSY_TIMEOUT_MS:-60000}"
    if [ "$mode" = "production" ]; then
      _gcp_yaml_kv DEPLOY_TIMESTAMP "${DEPLOY_TIMESTAMP}"
    fi
    # SCHEDULER_AUTH_TOKEN: production uses Secret Manager (see --set-secrets below).
    if [ "$mode" = "test" ] && [ -n "${SCHEDULER_AUTH_TOKEN:-}" ]; then
      _gcp_yaml_kv SCHEDULER_AUTH_TOKEN "${SCHEDULER_AUTH_TOKEN}"
    fi
    [ -n "${GCS_WEATHER_DATA_BUCKET:-}" ] && _gcp_yaml_kv GCS_WEATHER_DATA_BUCKET "${GCS_WEATHER_DATA_BUCKET}"
  } >"$env_file"

  local -a deploy_args=(
    run deploy "$SERVICE"
    --image "${IMAGE}"
    --region "$REGION"
    --platform managed
    --project "$PROJECT_ID"
    --service-account "$CLOUD_RUN_SA"
    --allow-unauthenticated
    --port 8080
    --cpu 2
    --memory 2Gi
    --timeout 600
    --max-instances 1
    --env-vars-file "$env_file"
  )

  if [ "$mode" = "production" ]; then
    # Cold start: /up is ready soon after agrr-server exec; avoid 60s initialDelay.
    deploy_args+=(
      --min-instances 1
      --startup-probe=initialDelaySeconds=10,timeoutSeconds=5,periodSeconds=5,failureThreshold=12,httpGet.path=/up,httpGet.port=8080
    )
    deploy_args+=(--set-secrets "SCHEDULER_AUTH_TOKEN=scheduler-auth-token:latest")
  fi

  echo "==> Deploying Cloud Run ${SERVICE} (port 8080)"
  gcloud "${deploy_args[@]}"

  local service_url
  service_url="$(gcloud run services describe "$SERVICE" --region "$REGION" --project "$PROJECT_ID" --format='value(status.url)')"
  echo "==> ${service_url}/up"

  if [ "${SKIP_HEALTH_CHECK:-0}" != "1" ]; then
    local health_url
    if [ "$mode" = "production" ]; then
      health_url="$(_agrr_server_production_health_url)"
      echo "==> Health check (LB /up; direct *.run.app is 404 with ingress=internal-and-cloud-load-balancing)"
    else
      health_url="${service_url}/up"
      echo "==> Health check (agrr-server /up)"
    fi
    echo "==> ${health_url}"
    local i body http_code
    for i in 1 2 3; do
      body="$(curl -sS "${health_url}" 2>/dev/null || true)"
      http_code="$(curl -sS -o /dev/null -w '%{http_code}' "${health_url}" 2>/dev/null || echo "?")"
      if [ "$body" = "ok" ] && [ "$http_code" = "200" ]; then
        echo "✓ Health OK"
        break
      fi
      if [ "$i" -eq 3 ]; then
        echo "ERROR: expected HTTP 200 body 'ok', got HTTP ${http_code} body: ${body:-<empty>}" >&2
        return 1
      fi
      echo "  waiting for LB/backend (${i}/3)..."
      sleep 5
    done
  fi

  if [ "$mode" = "test" ]; then
    export AGRR_TEST_API_URL="$service_url"
    local ui_script="${PROJECT_ROOT}/.cursor/skills/gcp-test-local/scripts/start-local-ui.sh"
    if [ -f "$ui_script" ]; then
      "$ui_script"
    else
      echo "WARN: start-local-ui.sh not found; UI not started" >&2
    fi
  fi

  if [ "$mode" = "production" ]; then
    echo "==> Done. LB cutover: docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md"
  fi
}
