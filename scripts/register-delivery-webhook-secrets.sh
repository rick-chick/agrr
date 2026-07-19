#!/usr/bin/env bash
# Register CURSOR_DELIVERY_WEBHOOK_* repository secrets for GitHub Actions.
#
# Requires a fine-grained PAT with repository permission **Secrets: Read and write**
# (AGRR_GH_SECRETS_PAT or AGRR_GH_PAT in Cursor Cloud Agent Secrets).
#
# Usage:
#   CURSOR_DELIVERY_WEBHOOK_URL=... CURSOR_DELIVERY_WEBHOOK_KEY=... \
#     ./scripts/register-delivery-webhook-secrets.sh
#
# Optional: REPO=owner/name (default rick-chick/agrr)
set -euo pipefail

REPO="${REPO:-rick-chick/agrr}"
URL="${CURSOR_DELIVERY_WEBHOOK_URL:-}"
KEY="${CURSOR_DELIVERY_WEBHOOK_KEY:-}"

if [[ -z "$URL" || -z "$KEY" ]]; then
  echo "register-delivery-webhook-secrets: set CURSOR_DELIVERY_WEBHOOK_URL and CURSOR_DELIVERY_WEBHOOK_KEY" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "register-delivery-webhook-secrets: gh not found" >&2
  exit 1
fi

unset GITHUB_TOKEN GH_TOKEN 2>/dev/null || true

if [[ -n "${AGRR_GH_SECRETS_PAT:-}" ]]; then
  echo "$AGRR_GH_SECRETS_PAT" | gh auth login --with-token
elif [[ -n "${AGRR_GH_PAT:-}" ]]; then
  echo "$AGRR_GH_PAT" | gh auth login --with-token
else
  echo "register-delivery-webhook-secrets: AGRR_GH_PAT or AGRR_GH_SECRETS_PAT required" >&2
  exit 1
fi

if ! gh api "repos/${REPO}/actions/secrets/public-key" --jq .key_id >/dev/null 2>&1; then
  echo "register-delivery-webhook-secrets: PAT lacks Secrets API access (add Secrets: Read and write on fine-grained token)" >&2
  exit 1
fi

printf '%s' "$URL" | gh secret set CURSOR_DELIVERY_WEBHOOK_URL --repo "$REPO"
printf '%s' "$KEY" | gh secret set CURSOR_DELIVERY_WEBHOOK_KEY --repo "$REPO"

echo "Registered CURSOR_DELIVERY_WEBHOOK_URL and CURSOR_DELIVERY_WEBHOOK_KEY on ${REPO}"
