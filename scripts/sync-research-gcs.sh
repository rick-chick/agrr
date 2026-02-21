#!/bin/bash
set -e

PROJECT_ID="agrr-475323"
BUCKET="agrr-research-backend"

echo "[INFO]" "Syncing Research Assets to GCS bucket gs://${BUCKET}"

gsutil -m rsync -r -d public/research gs://${BUCKET}/

echo "[INFO]" "Setting cache headers for HTML files (no-cache)"
gsutil -m setmeta -h "Cache-Control:no-cache,max-age=0,must-revalidate" gs://${BUCKET}/**/*.html gs://${BUCKET}/404.html || true

echo "[INFO]" "Setting immutable cache for assets"
gsutil -m setmeta -h "Cache-Control:public,max-age=31536000,immutable" \\
  'gs://${BUCKET}/**/*.js' \\
  'gs://${BUCKET}/**/*.css' \\
  'gs://${BUCKET}/**/*.png' \\
  'gs://${BUCKET}/**/*.jpg' \\
  'gs://${BUCKET}/**/*.svg' \\
  'gs://${BUCKET}/**/*.woff*' \\
  'gs://${BUCKET}/**/*.ttf' || true

echo "[INFO]" "Research sync and cache setup completed ✓"
