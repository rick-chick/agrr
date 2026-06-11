#!/usr/bin/env bash
# Submit sitemap to Google Search Console via Webmasters API v3.
# Requires OAuth with https://www.googleapis.com/auth/webmasters scope (one-time setup):
#   gcloud auth application-default login \
#     --scopes="openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/webmasters"
#   gcloud auth application-default set-quota-project agrr-475323
set -euo pipefail

SITE_URL="${GSC_SITE_URL:-sc-domain:agrr.net}"
SITEMAP_URL="${GSC_SITEMAP_URL:-https://agrr.net/sitemap.xml}"
QUOTA_PROJECT="${GSC_QUOTA_PROJECT:-agrr-475323}"

if ! command -v gcloud >/dev/null; then
  echo "ERROR: gcloud not found" >&2
  exit 1
fi

TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: No application-default credentials. Run:" >&2
  echo "  gcloud auth application-default login --scopes=\"openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/webmasters\"" >&2
  echo "  gcloud auth application-default set-quota-project agrr-475323" >&2
  exit 1
fi

SITE_ENC="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$SITE_URL")"
SITEMAP_ENC="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$SITEMAP_URL")"

RESP="$(mktemp)"
HTTP_CODE="$(curl -sS -o "$RESP" -w '%{http_code}' -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: ${QUOTA_PROJECT}" \
  -H "Content-Length: 0" \
  "https://www.googleapis.com/webmasters/v3/sites/${SITE_ENC}/sitemaps/${SITEMAP_ENC}")"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
  echo "OK: submitted $SITEMAP_URL for property $SITE_URL (HTTP $HTTP_CODE)"
  rm -f "$RESP"
  exit 0
fi

echo "FAIL: HTTP $HTTP_CODE" >&2
cat "$RESP" >&2
rm -f "$RESP"
exit 1
