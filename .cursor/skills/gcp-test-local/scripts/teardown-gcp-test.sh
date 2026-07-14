#!/usr/bin/env bash
# Tear down GCP test-only resources in project agrr-475323.
# Does NOT delete production (agrr-production, agrr-production-db, agrr-frontend-prod,
# agrr-server images), shared agrr-weather-data, project, LB, or OAuth/DNS.
#
#   .cursor/skills/gcp-test-local/scripts/teardown-gcp-test.sh
#   .cursor/skills/gcp-test-local/scripts/teardown-gcp-test.sh --quiet
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "ERROR: repository root not found (git rev-parse failed)" >&2
  exit 1
fi

QUIET=false
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=true ;;
    -h | --help)
      echo "Usage: $0 [--quiet]" >&2
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

REQUIRED_PROJECT="agrr-475323"
REQUIRED_SERVICE="agrr-test"
REQUIRED_IMAGE="agrr-test"
ALLOWED_BUCKETS=(agrr-test-db agrr-frontend-test)
BLOCKED_NAMES=(agrr-production agrr-production-db agrr-frontend-prod agrr-server)

PROJECT_ID="${PROJECT_ID:-agrr-475323}"
REGION="${REGION:-asia-northeast1}"
SERVICE="${SERVICE_NAME:-agrr-test}"
IMAGE_NAME="${IMAGE_NAME:-agrr-test}"
REGISTRY="${REGISTRY:-asia-northeast1-docker.pkg.dev}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

assert_not_blocked() {
  local name=$1
  local label=$2
  local blocked
  for blocked in "${BLOCKED_NAMES[@]}"; do
    if [ "$name" = "$blocked" ]; then
      die "refusing ${label} '${name}' (production or protected name)"
    fi
  done
}

assert_project() {
  if [ "$PROJECT_ID" != "$REQUIRED_PROJECT" ]; then
    die "PROJECT_ID must be ${REQUIRED_PROJECT} (got: ${PROJECT_ID})"
  fi
}

assert_test_service() {
  assert_not_blocked "$SERVICE" "Cloud Run service"
  if [ "$SERVICE" != "$REQUIRED_SERVICE" ]; then
    die "SERVICE_NAME must be ${REQUIRED_SERVICE} (got: ${SERVICE})"
  fi
}

assert_test_image() {
  assert_not_blocked "$IMAGE_NAME" "Artifact Registry image"
  if [ "$IMAGE_NAME" != "$REQUIRED_IMAGE" ]; then
    die "IMAGE_NAME must be ${REQUIRED_IMAGE} (got: ${IMAGE_NAME})"
  fi
}

assert_allowed_bucket() {
  local bucket=$1
  assert_not_blocked "$bucket" "GCS bucket"
  local allowed
  for allowed in "${ALLOWED_BUCKETS[@]}"; do
    if [ "$bucket" = "$allowed" ]; then
      return 0
    fi
  done
  die "GCS bucket '${bucket}' is not on the test allowlist (${ALLOWED_BUCKETS[*]})"
}

confirm() {
  if [ "$QUIET" = true ]; then
    return 0
  fi
  echo "This deletes GCP test resources in project ${PROJECT_ID}."
  echo "  Cloud Run: ${SERVICE}"
  echo "  GCS: ${ALLOWED_BUCKETS[*]}"
  echo "  Images: ${REGISTRY}/${PROJECT_ID}/agrr/${IMAGE_NAME}"
  echo "Production resources are NOT targeted."
  printf "Type '%s' to continue: " "$REQUIRED_SERVICE"
  read -r answer
  if [ "$answer" != "$REQUIRED_SERVICE" ]; then
    die "confirmation failed (expected: ${REQUIRED_SERVICE})"
  fi
}

delete_cloud_run() {
  if ! gcloud run services describe "$SERVICE" \
    --region "$REGION" --project "$PROJECT_ID" >/dev/null 2>&1; then
    info "Cloud Run service ${SERVICE} not found (skip)"
    return 0
  fi
  info "Deleting Cloud Run service ${SERVICE}"
  gcloud run services delete "$SERVICE" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet
}

empty_and_delete_bucket() {
  local bucket=$1
  assert_allowed_bucket "$bucket"
  local uri="gs://${bucket}"
  if ! gcloud storage buckets describe "$uri" --project "$PROJECT_ID" >/dev/null 2>&1; then
    info "Bucket ${uri} not found (skip)"
    return 0
  fi
  info "Deleting objects in ${uri}"
  gcloud storage rm -r "${uri}/**" --project "$PROJECT_ID" 2>/dev/null || true
  info "Deleting bucket ${uri}"
  gcloud storage buckets delete "$uri" --project "$PROJECT_ID" --quiet
}

delete_artifact_images() {
  local image_path="${REGISTRY}/${PROJECT_ID}/agrr/${IMAGE_NAME}"
  local images=()
  while IFS= read -r line; do
    [ -n "$line" ] && images+=("$line")
  done < <(
    gcloud artifacts docker images list "$image_path" \
      --include-tags \
      --format='value(image)' 2>/dev/null || true
  )
  if [ "${#images[@]}" -eq 0 ]; then
    info "No Artifact Registry images under ${image_path} (skip)"
    return 0
  fi
  local img
  for img in "${images[@]}"; do
    info "Deleting image ${img}"
    gcloud artifacts docker images delete "$img" --quiet --delete-tags
  done
}

assert_project
assert_test_service
assert_test_image
confirm

delete_cloud_run
for bucket in "${ALLOWED_BUCKETS[@]}"; do
  empty_and_delete_bucket "$bucket"
done
delete_artifact_images

info "GCP test tear-down complete"
info "Manual: Google OAuth redirect URIs, DNS agrr-test.net (if configured)"
info "Re-deploy: .cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh test"
