#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

PROJECT_ID="${PROJECT_ID:-agrr-475323}"
BUCKET="${BUCKET:-agrr-research-backend}"
FRONTEND_BUCKET="${FRONTEND_BUCKET:-agrr-frontend-prod}"
GENERATE_SITEMAP="${ROOT_DIR}/.cursor/skills/deploy-frontend/scripts/generate-sitemap.mjs"

echo "[INFO] Syncing Research Assets to GCS bucket gs://${BUCKET}"

ruby "${SCRIPT_DIR}/inject-research-google-analytics.rb"

gsutil -m rsync -r -d "${ROOT_DIR}/public/research" "gs://${BUCKET}/"

echo "[INFO] Setting cache headers for HTML files (no-cache)"
gsutil -m setmeta -h "Cache-Control:no-cache,max-age=0,must-revalidate" \
  "gs://${BUCKET}/**/*.html" "gs://${BUCKET}/404.html" || true

echo "[INFO] Setting immutable cache for assets"
gsutil -m setmeta -h "Cache-Control:public,max-age=31536000,immutable" \
  "gs://${BUCKET}/**/*.js" \
  "gs://${BUCKET}/**/*.css" \
  "gs://${BUCKET}/**/*.png" \
  "gs://${BUCKET}/**/*.jpg" \
  "gs://${BUCKET}/**/*.svg" \
  "gs://${BUCKET}/**/*.woff*" \
  "gs://${BUCKET}/**/*.ttf" || true

echo "[INFO] Regenerating sitemap and uploading to frontend bucket"
node "$GENERATE_SITEMAP"
gsutil cp "${ROOT_DIR}/frontend/public/sitemap.xml" "gs://${FRONTEND_BUCKET}/sitemap.xml"
gsutil setmeta -h "Cache-Control:no-cache,max-age=0,must-revalidate" "gs://${FRONTEND_BUCKET}/sitemap.xml"

echo "[INFO] Research sync and sitemap update completed"
