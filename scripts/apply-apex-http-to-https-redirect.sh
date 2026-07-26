#!/usr/bin/env bash
# Apply apex HTTP (port 80) → HTTPS 301 redirect on production LB.
# Usage: scripts/apply-apex-http-to-https-redirect.sh [--dry-run]
set -eu

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT_DIR/scripts/agrr-http-to-https-redirect-manifest.yaml"
URL_MAP_SOURCE="$ROOT_DIR/scripts/agrr-http-to-https-redirect-url-map.yaml"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${1:-}" ]]; then
  die "usage: $0 [--dry-run]"
fi

command -v gcloud >/dev/null 2>&1 || die "gcloud not found in PATH"
[[ -f "$MANIFEST" ]] || die "missing $MANIFEST"
[[ -f "$URL_MAP_SOURCE" ]] || die "missing $URL_MAP_SOURCE"

read_manifest() {
  awk -v key="$1" '
    $1 == key ":" {
      val = $2
      sub(/#.*/, "", val)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ' "$MANIFEST"
}

read_nested_manifest() {
  local section="$1"
  local key="$2"
  awk -v section="$section:" -v key="$key:" '
    $1 == section { in_section = 1; next }
    in_section && /^[^[:space:]]/ { in_section = 0 }
    in_section && $1 == key {
      val = $2
      sub(/#.*/, "", val)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      print val
      exit
    }
  ' "$MANIFEST"
}

PROJECT="${GCP_PROJECT:-$(read_manifest project)}"
PROJECT="${PROJECT:-agrr-475323}"
URL_MAP_NAME="$(read_nested_manifest urlMap name)"
TARGET_PROXY_NAME="$(read_nested_manifest targetHttpProxy name)"
FORWARDING_RULE_NAME="$(read_nested_manifest forwardingRule name)"
GLOBAL_ADDRESS="$(read_manifest globalAddress)"
PORT_RANGE="$(read_nested_manifest forwardingRule portRange)"
PORT_RANGE="${PORT_RANGE:-80-80}"

[[ -n "$URL_MAP_NAME" ]] || die "urlMap.name missing in manifest"
[[ -n "$TARGET_PROXY_NAME" ]] || die "targetHttpProxy.name missing in manifest"
[[ -n "$FORWARDING_RULE_NAME" ]] || die "forwardingRule.name missing in manifest"
[[ -n "$GLOBAL_ADDRESS" ]] || die "globalAddress missing in manifest"

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "DRY RUN: $*"
  else
    info "Running: $*"
    "$@"
  fi
}

info "Project=$PROJECT urlMap=$URL_MAP_NAME proxy=$TARGET_PROXY_NAME rule=$FORWARDING_RULE_NAME address=$GLOBAL_ADDRESS"

run_cmd gcloud compute url-maps validate "$URL_MAP_NAME" \
  --source="$URL_MAP_SOURCE" --global --project="$PROJECT"

run_cmd gcloud compute url-maps import "$URL_MAP_NAME" \
  --source="$URL_MAP_SOURCE" --global --project="$PROJECT" --quiet

if gcloud compute target-http-proxies describe "$TARGET_PROXY_NAME" --global --project="$PROJECT" >/dev/null 2>&1; then
  run_cmd gcloud compute target-http-proxies update "$TARGET_PROXY_NAME" \
    --url-map="$URL_MAP_NAME" --global --project="$PROJECT" --quiet
else
  run_cmd gcloud compute target-http-proxies create "$TARGET_PROXY_NAME" \
    --url-map="$URL_MAP_NAME" --global --project="$PROJECT" --quiet
fi

if gcloud compute forwarding-rules describe "$FORWARDING_RULE_NAME" --global --project="$PROJECT" >/dev/null 2>&1; then
  info "Forwarding rule $FORWARDING_RULE_NAME already exists (no recreate)"
else
  run_cmd gcloud compute forwarding-rules create "$FORWARDING_RULE_NAME" \
    --target-http-proxy="$TARGET_PROXY_NAME" \
    --address="$GLOBAL_ADDRESS" \
    --global \
    --ports="$PORT_RANGE" \
    --project="$PROJECT" \
    --quiet
fi

info "Done. Verify with: curl -sI http://agrr.net/"
