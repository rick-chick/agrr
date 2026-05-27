# shellcheck shell=bash
# Resolve HTTPS base URL for production API calls.
# Cloud Run ingress is often "internal-and-cloud-load-balancing"; *.run.app may return 404.
#
# Priority:
#   1. PRODUCTION_PUBLIC_URL (from .env.gcp)
#   2. First non-wildcard host in ALLOWED_HOSTS → https://host
#   3. gcloud run services describe status.url (with warning)

resolve_production_public_url() {
  SERVICE_URL=""

  if [ -n "${PRODUCTION_PUBLIC_URL:-}" ]; then
    SERVICE_URL="${PRODUCTION_PUBLIC_URL%/}"
    return 0
  fi

  if [ -n "${ALLOWED_HOSTS:-}" ]; then
    local host
    while IFS= read -r host; do
      host="${host// /}"
      [ -z "$host" ] && continue
      [[ "$host" == .* ]] && continue
      SERVICE_URL="https://${host}"
      return 0
    done < <(printf '%s' "$ALLOWED_HOSTS" | tr ',' '\n')
  fi

  local service_name region
  service_name="${SERVICE_NAME:-agrr-production}"
  region="${REGION:-asia-northeast1}"
  if [ -n "${PROJECT_ID:-}" ]; then
    SERVICE_URL="$(gcloud run services describe "$service_name" --region "$region" --project "$PROJECT_ID" --format 'value(status.url)' 2>/dev/null || true)"
  fi
  if [ -z "$SERVICE_URL" ]; then
    SERVICE_URL="$(gcloud run services describe "$service_name" --region "$region" --format 'value(status.url)' 2>/dev/null || true)"
  fi

  if [ -n "$SERVICE_URL" ]; then
    print_warning "Using Cloud Run URL ($SERVICE_URL). Direct *.run.app access may 404 when ingress is load-balancer only."
    print_warning "Set PRODUCTION_PUBLIC_URL=https://agrr.net in .env.gcp or use ALLOWED_HOSTS."
  fi
}
