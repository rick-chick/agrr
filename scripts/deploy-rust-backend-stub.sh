#!/usr/bin/env bash
# Deploy agrr-server to Cloud Run as rust-backend (P6 strangler stub).
# URL map rules are added per BC cutover PR (see ADR-strangler-lb-url-map.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT_ID="${GCP_PROJECT_ID:-agrr-475323}"
REGION="${GCP_REGION:-asia-northeast1}"
SERVICE="agrr-server"
IMAGE="asia-northeast1-docker.pkg.dev/${PROJECT_ID}/agrr/${SERVICE}:latest"

echo "==> Building ${IMAGE}"
docker build -f Dockerfile.agrr-server -t "${IMAGE}" .

echo "==> Pushing image"
docker push "${IMAGE}"

echo "==> Deploying Cloud Run service ${SERVICE}"
gcloud run deploy "${SERVICE}" \
  --image "${IMAGE}" \
  --region "${REGION}" \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars "AGRR_ENV=production" \
  --project "${PROJECT_ID}"

echo "==> Done. Add URL map pathRules for migrated routes before sending production traffic."
