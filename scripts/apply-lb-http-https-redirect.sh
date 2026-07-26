#!/usr/bin/env bash
# Apply apex HTTP (port 80) → HTTPS 301 redirect on the production global LB.
# Creates/updates URL map, target-http-proxy, and port-80 forwarding rule on the
# same global address as the primary HTTPS listener.
#
# Usage: scripts/apply-lb-http-https-redirect.sh [--dry-run]
set -eu

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES_FILE="$ROOT_DIR/scripts/agrr-http-https-redirect-resources.yaml"
URL_MAP_FILE="$ROOT_DIR/scripts/agrr-http-https-redirect-url-map.yaml"
PROJECT="${GCP_PROJECT:-$(awk '/^project:/{print $2}' "$RESOURCES_FILE")}"
PROJECT="${PROJECT:-agrr-475323}"
DRY_RUN=0

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${1:-}" ]]; then
  die "usage: $0 [--dry-run]"
fi

command -v gcloud >/dev/null 2>&1 || die "gcloud not found in PATH"
[[ -f "$RESOURCES_FILE" ]] || die "missing $RESOURCES_FILE"
[[ -f "$URL_MAP_FILE" ]] || die "missing $URL_MAP_FILE"

URL_MAP_NAME="$(awk '/^urlMap:/{getline; if ($1 == "name:") print $2}' "$RESOURCES_FILE")"
HTTPS_URL_MAP="$(awk '/^httpsUrlMap:/{getline; if ($1 == "name:") print $2}' "$RESOURCES_FILE")"
PROXY_NAME="$(awk '/^targetHttpProxy:/{getline; if ($1 == "name:") print $2}' "$RESOURCES_FILE")"
FORWARDING_RULE_NAME="$(awk '/^forwardingRule:/{getline; if ($1 == "name:") print $2}' "$RESOURCES_FILE")"
PORT_RANGE="$(awk '/^forwardingRule:/{found=1} found && $1 == "portRange:" {print $2; exit}' "$RESOURCES_FILE")"

[[ -n "$URL_MAP_NAME" ]] || die "urlMap.name missing in $RESOURCES_FILE"
[[ -n "$HTTPS_URL_MAP" ]] || die "httpsUrlMap.name missing in $RESOURCES_FILE"
[[ -n "$PROXY_NAME" ]] || die "targetHttpProxy.name missing in $RESOURCES_FILE"
[[ -n "$FORWARDING_RULE_NAME" ]] || die "forwardingRule.name missing in $RESOURCES_FILE"
PORT_RANGE="${PORT_RANGE:-80}"

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "DRY RUN: $*"
  else
  "$@"
  fi
}

info "Validating URL map $URL_MAP_NAME"
run_cmd gcloud compute url-maps validate "$URL_MAP_NAME" \
  --source="$URL_MAP_FILE" \
  --global \
  --project="$PROJECT"

if gcloud compute url-maps describe "$URL_MAP_NAME" --global --project="$PROJECT" >/dev/null 2>&1; then
  info "Importing URL map $URL_MAP_NAME"
  run_cmd gcloud compute url-maps import "$URL_MAP_NAME" \
    --source="$URL_MAP_FILE" \
    --global \
    --project="$PROJECT" \
    --quiet
else
  info "Creating URL map $URL_MAP_NAME"
  run_cmd gcloud compute url-maps import "$URL_MAP_NAME" \
    --source="$URL_MAP_FILE" \
    --global \
    --project="$PROJECT" \
    --quiet
fi

if gcloud compute target-http-proxies describe "$PROXY_NAME" --global --project="$PROJECT" >/dev/null 2>&1; then
  info "Target HTTP proxy $PROXY_NAME already exists"
else
  info "Creating target HTTP proxy $PROXY_NAME"
  run_cmd gcloud compute target-http-proxies create "$PROXY_NAME" \
    --url-map="$URL_MAP_NAME" \
    --global \
    --project="$PROJECT"
fi

HTTPS_PROXY="$(gcloud compute target-https-proxies list \
  --project="$PROJECT" \
  --filter="urlMap~${HTTPS_URL_MAP}" \
  --format="value(name)" | head -1)"
[[ -n "$HTTPS_PROXY" ]] || die "no HTTPS proxy found for url map ${HTTPS_URL_MAP}"

HTTPS_FORWARDING_RULE="$(gcloud compute forwarding-rules list \
  --global \
  --project="$PROJECT" \
  --filter="target~${HTTPS_PROXY}" \
  --format="value(name)" | head -1)"
[[ -n "$HTTPS_FORWARDING_RULE" ]] || die "no global forwarding rule found for HTTPS proxy ${HTTPS_PROXY}"

ADDRESS_RESOURCE="$(gcloud compute forwarding-rules describe "$HTTPS_FORWARDING_RULE" \
  --global \
  --project="$PROJECT" \
  --format="value(address)")"
[[ -n "$ADDRESS_RESOURCE" ]] || die "HTTPS forwarding rule ${HTTPS_FORWARDING_RULE} has no address"
ADDRESS_NAME="${ADDRESS_RESOURCE##*/}"

if gcloud compute forwarding-rules describe "$FORWARDING_RULE_NAME" --global --project="$PROJECT" >/dev/null 2>&1; then
  info "Forwarding rule $FORWARDING_RULE_NAME already exists"
else
  info "Creating forwarding rule $FORWARDING_RULE_NAME on address $ADDRESS_NAME port $PORT_RANGE"
  run_cmd gcloud compute forwarding-rules create "$FORWARDING_RULE_NAME" \
    --global \
    --project="$PROJECT" \
    --target-http-proxy="$PROXY_NAME" \
    --address="$ADDRESS_NAME" \
    --ports="$PORT_RANGE"
fi

info "Done. Verify with: curl -sI http://agrr.net/"
