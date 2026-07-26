#!/usr/bin/env bash
# Apply canonical security response headers to production LB backends.
# Usage: scripts/apply-lb-security-response-headers.sh [--dry-run]
set -eu

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HEADERS_FILE="$ROOT_DIR/scripts/agrr-security-response-headers.yaml"
BACKENDS_FILE="$ROOT_DIR/scripts/agrr-lb-backend-security-headers.yaml"
PROJECT="${GCP_PROJECT:-$(awk '/^project:/{print $2}' "$BACKENDS_FILE")}"
PROJECT="${PROJECT:-agrr-475323}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${1:-}" ]]; then
  die "usage: $0 [--dry-run]"
fi

command -v gcloud >/dev/null 2>&1 || die "gcloud not found in PATH"
[[ -f "$HEADERS_FILE" ]] || die "missing $HEADERS_FILE"
[[ -f "$BACKENDS_FILE" ]] || die "missing $BACKENDS_FILE"

mapfile -t HEADER_FLAGS < <(
  awk '
    /^[[:space:]]*-[[:space:]]*"/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*"/, "", line)
      sub(/"[[:space:]]*$/, "", line)
      if (line != "") print line
    }
  ' "$HEADERS_FILE" | while IFS= read -r header; do
    printf -- '--custom-response-header=%q\n' "$header"
  done
)

if [[ "${#HEADER_FLAGS[@]}" -eq 0 ]]; then
  die "no headers parsed from $HEADERS_FILE"
fi

apply_backend_bucket() {
  local name="$1"
  local -a cmd=(gcloud compute backend-buckets update "$name" --global --project="$PROJECT")
  local flag
  for flag in "${HEADER_FLAGS[@]}"; do
    cmd+=("$flag")
  done
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "DRY RUN: ${cmd[*]}"
  else
    info "Updating backend bucket $name"
    "${cmd[@]}"
  fi
}

apply_backend_service() {
  local name="$1"
  local -a cmd=(gcloud compute backend-services update "$name" --global --project="$PROJECT")
  local flag
  for flag in "${HEADER_FLAGS[@]}"; do
    cmd+=("$flag")
  done
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "DRY RUN: ${cmd[*]}"
  else
    info "Updating backend service $name"
    "${cmd[@]}"
  fi
}

mapfile -t BUCKET_BACKENDS < <(
  awk '/backendBuckets:/{flag=1; next} /backendServices:/{flag=0} flag && /^[[:space:]]*-[[:space:]]*/ {gsub(/^[[:space:]]*-[[:space:]]*/, ""); print}' "$BACKENDS_FILE"
)
mapfile -t SERVICE_BACKENDS < <(
  awk '/backendServices:/{flag=1; next} flag && /^[[:space:]]*-[[:space:]]*/ {gsub(/^[[:space:]]*-[[:space:]]*/, ""); print}' "$BACKENDS_FILE"
)

for backend in "${BUCKET_BACKENDS[@]}"; do
  [[ -n "$backend" ]] || continue
  apply_backend_bucket "$backend"
done

for backend in "${SERVICE_BACKENDS[@]}"; do
  [[ -n "$backend" ]] || continue
  apply_backend_service "$backend"
done

info "Done. Verify with: curl -sI https://agrr.net/ && curl -sI https://agrr.net/api/v1/health"
