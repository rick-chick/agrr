#!/usr/bin/env bash
# Deploy Angular static build to a GCS bucket and invalidate Cloud CDN.
# Usage:
#   ./scripts/gcp-frontend-deploy.sh deploy test     # uses .env.gcp.frontend.test
#   ./scripts/gcp-frontend-deploy.sh deploy production
#
# Environment variables (required or loaded from env file):
#   PROJECT_ID
#   REGION
#   BUCKET_NAME
#   API_BASE_URL
#   URL_MAP_NAME            # used for CDN invalidation (optional)
#   DRY_RUN=1               # set to "1" to print commands instead of executing
#
set -eu

# Helpers
die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "INFO: $*"; }

# Ensure required programs exist
command -v gsutil >/dev/null 2>&1 || die "gsutil not found in PATH"
command -v gcloud >/dev/null 2>&1 || die "gcloud not found in PATH"
command -v npm >/dev/null 2>&1 || die "npm not found in PATH"

if [ "$#" -ne 2 ] || [ "$1" != "deploy" ]; then
  cat <<EOF
Usage:
  $0 deploy <test|production>
Examples:
  $0 deploy test
  $0 deploy production
EOF
  exit 2
fi

ENV="$2"
ROOT_DIR="$(pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_CMD="npm run build -- --prod"

# Load environment file
ENV_FILE=".env.gcp.frontend"
if [ "$ENV" = "test" ]; then
  ENV_FILE=".env.gcp.frontend.test"
fi

if [ ! -f "$ENV_FILE" ]; then
  die "Environment file '$ENV_FILE' not found. Create it or pass required env vars."
fi

# shellcheck disable=SC1090
set -a
# support lines like KEY=VALUE in env file
# Use '.' to source for POSIX-ish, but this script runs under bash
. "$ENV_FILE"
set +a

# Ensure required variables are present
: "${PROJECT_ID:?PROJECT_ID must be set (from env file)}"
: "${BUCKET_NAME:?BUCKET_NAME must be set (from env file)}"
: "${API_BASE_URL:?API_BASE_URL must be set (from env file)}"
# URL_MAP_NAME is optional, used for CDN invalidation
# CDN_BACKEND_SERVICE optional (not used by default)

DRY_RUN="${DRY_RUN:-0}"

run() {
  if [ "${DRY_RUN}" = "1" ]; then
    echo "[DRY-RUN] $*"
  else
    echo "[RUN] $*"
    eval "$@"
  fi
}

# Safety check: bucket name looks sane
case "$BUCKET_NAME" in
  *[A-Z]* | *_* )
    die "BUCKET_NAME appears to contain uppercase letters or underscores. Use lowercase letters, numbers and dashes."
    ;;
esac

info "Building frontend for '$ENV'..."
cd "$ROOT_DIR"
# install deps and build
if [ "${DRY_RUN}" = "1" ]; then
  info "Skipping npm install/build in dry-run"
else
  npm ci
  npm run build -- --configuration="$ENV" || npm run build || true
  # Some repos use plain 'npm run build' and not configuration flags; fall back to simple build
fi

# locate built dist directory
# Allow for common Angular output dirs: dist/, dist/<project>/
if [ -d "$DIST_DIR" ] && [ "$(ls -A "$DIST_DIR")" ]; then
  BUILD_OUTPUT_DIR="$DIST_DIR"
else
  # try nested
  FIRST_OUTPUT="$(ls -1 "$DIST_DIR" 2>/dev/null | head -n1 || true)"
  if [ -n "$FIRST_OUTPUT" ] && [ -d "$DIST_DIR/$FIRST_OUTPUT" ]; then
    BUILD_OUTPUT_DIR="$DIST_DIR/$FIRST_OUTPUT"
  else
    die "Could not find build output in $DIST_DIR"
  fi
fi

info "Build output directory: $BUILD_OUTPUT_DIR"

# Inject API_BASE_URL at runtime into index.html
INDEX_HTML="$BUILD_OUTPUT_DIR/index.html"
if [ ! -f "$INDEX_HTML" ]; then
  die "index.html not found in build output: $INDEX_HTML"
fi

# Prepare injection snippet (safe JSON string)
json_escape() {
  python3 - <<PY - "${1:-}"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

# Fallback if python3 not available
if command -v python3 >/dev/null 2>&1; then
  API_JSON=$(json_escape "$API_BASE_URL")
else
  # minimal escaping: wrap in double quotes and escape existing double quotes and backslashes
  esc=$(printf '%s' "$API_BASE_URL" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  API_JSON="\"$esc\""
fi

INJECT_SNIPPET="<script>window.API_BASE_URL = $API_JSON;</script>"

# Insert snippet before first </head> or before first </body> if head not present
TMP_INDEX="$(mktemp)"
awk -v snippet="$INJECT_SNIPPET" 'BEGIN{added=0}
  tolower($0) ~ /<\/head>/ && !added {
    print snippet
    added=1
  }
  { print }
  END { if(!added) { print snippet } }' "$INDEX_HTML" > "$TMP_INDEX"

run mv "$TMP_INDEX" "$INDEX_HTML"

# Sync to GCS bucket
GCS_TARGET="gs://$BUCKET_NAME"
info "Syncing to $GCS_TARGET"
# Use rsync: delete removed files (-d), recursive (-r), multithreaded via -m
run gsutil -m rsync -r -d "$BUILD_OUTPUT_DIR" "$GCS_TARGET"

# Set cache-control metadata
info "Setting Cache-Control metadata"
# index.html -> no-cache
run gsutil setmeta -h "Cache-Control: no-cache, max-age=0, must-revalidate" "$GCS_TARGET/index.html"

# Long cache for common static asset extensions
ASSET_PATTERNS=(
  "$GCS_TARGET/**/*.js"
  "$GCS_TARGET/**/*.css"
  "$GCS_TARGET/**/*.woff2"
  "$GCS_TARGET/**/*.woff"
  "$GCS_TARGET/**/*.ttf"
  "$GCS_TARGET/**/*.png"
  "$GCS_TARGET/**/*.jpg"
  "$GCS_TARGET/**/*.svg"
)

for pattern in "${ASSET_PATTERNS[@]}"; do
  run gsutil -m setmeta -h "Cache-Control: public, max-age=31536000, immutable" "$pattern" || true
done

# Optionally make objects publicly readable (if desired)
PUBLIC_READ="${PUBLIC_READ:-0}"
if [ "$PUBLIC_READ" = "1" ]; then
  info "Making objects public (allUsers:objectViewer)"
  run gsutil iam ch allUsers:objectViewer "$GCS_TARGET" || true
fi

# CDN invalidation
if [ -n "${URL_MAP_NAME:-}" ]; then
  info "Invalidating CDN cache via URL map: $URL_MAP_NAME"
  run gcloud compute url-maps invalidate-cdn-cache "$URL_MAP_NAME" --path "/*" --project "$PROJECT_ID"
else
  info "No URL_MAP_NAME provided; skipping CDN invalidation. If you use Cloud CDN, consider setting URL_MAP_NAME to run invalidate-cdn-cache."
fi

info "Deployment completed for env='$ENV' to bucket='$BUCKET_NAME'."

