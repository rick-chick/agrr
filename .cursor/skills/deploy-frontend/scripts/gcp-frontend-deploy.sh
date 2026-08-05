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
#   GOOGLE_ADS_CONVERSION_ID   # optional AW-… for gtag config (injected into index.html)
#   GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO # optional AW-…/label — login conversion ping
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
FRONTEND_DIR="$ROOT_DIR/frontend"
DIST_DIR="$FRONTEND_DIR/dist"

if [ ! -d "$FRONTEND_DIR" ]; then
  die "Frontend directory not found at '$FRONTEND_DIR'."
fi

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
# Optional Google Ads conversion (see env.example GOOGLE_ADS_*)
GOOGLE_ADS_CONVERSION_ID="${GOOGLE_ADS_CONVERSION_ID:-}"
GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO="${GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO:-}"
# Static path prefix for assets (used in deploy-url)
STATIC_PATH_PREFIX="${STATIC_PATH_PREFIX:-static}"
# URL_MAP_NAME is optional, used for CDN invalidation
# CDN_BACKEND_SERVICE optional (not used by default)

DRY_RUN="${DRY_RUN:-0}"

run() {
  if [ "${DRY_RUN}" = "1" ]; then
    echo "[DRY-RUN] $*"
  else
    echo "[RUN] $*"
    "$@"
  fi
}

# Safety check: bucket name looks sane
case "$BUCKET_NAME" in
  *[A-Z]* | *_* )
    die "BUCKET_NAME appears to contain uppercase letters or underscores. Use lowercase letters, numbers and dashes."
    ;;
esac

info "Generating sitemap.xml..."
run node "$ROOT_DIR/.cursor/skills/deploy-frontend/scripts/generate-sitemap.mjs"

info "Building frontend for '$ENV'..."
cd "$ROOT_DIR"
# Determine Angular configuration for each env
case "$ENV" in
  production)
    BUILD_CONFIGURATION="production"
    ;;
  test)
    BUILD_CONFIGURATION="development"
    ;;
  *)
    BUILD_CONFIGURATION="$ENV"
    ;;
esac

# install deps and build
if [ "${DRY_RUN}" = "1" ]; then
  info "Skipping npm install/build in dry-run"
else
  (
    cd "$FRONTEND_DIR"
  run npm ci
  run npm run build -- --configuration="$BUILD_CONFIGURATION" --deploy-url="/$STATIC_PATH_PREFIX/"
  )
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

# @angular/build:application outputs to <dist>/<project>/browser/ (prerender routes add nested index.html).
if [ -f "$BUILD_OUTPUT_DIR/browser/index.html" ]; then
  BUILD_OUTPUT_DIR="$BUILD_OUTPUT_DIR/browser"
fi

# Fallback: pick the shallowest index.html (never a prerender route like contact/index.html).
if [ ! -f "$BUILD_OUTPUT_DIR/index.html" ]; then
  INDEX_FILE="$(find "$DIST_DIR" -name index.html -print 2>/dev/null \
    | awk -F/ '{ print NF, $0 }' | sort -n | head -1 | cut -d' ' -f2-)"
  if [ -n "$INDEX_FILE" ]; then
    BUILD_OUTPUT_DIR="$(dirname "$INDEX_FILE")"
  fi
fi

# After build we want static assets behind $STATIC_PATH_PREFIX/
STATIC_OUTPUT_DIR="$BUILD_OUTPUT_DIR/$STATIC_PATH_PREFIX"
info "Build output directory: $BUILD_OUTPUT_DIR (static assets under /$STATIC_PATH_PREFIX/)"

# Move everything except index.html, favicon.ico, and the static directory itself
shopt -s dotglob nullglob
mkdir -p "$STATIC_OUTPUT_DIR"
for entry in "$BUILD_OUTPUT_DIR"/?* "$BUILD_OUTPUT_DIR"/.[!.]* "$BUILD_OUTPUT_DIR"/..?*; do
  [ -e "$entry" ] || continue
  name="$(basename "$entry")"
  if [ "$name" = "index.html" ] || [ "$name" = "favicon.ico" ] \
    || [ "$name" = "robots.txt" ] || [ "$name" = "sitemap.xml" ] || [ "$name" = "404.html" ] \
    || [ "$name" = "$STATIC_PATH_PREFIX" ]; then
    continue
  fi
  run mv "$entry" "$STATIC_OUTPUT_DIR/"
done
shopt -u dotglob nullglob


# Inject API_BASE_URL at runtime into index.html
INDEX_HTML="$BUILD_OUTPUT_DIR/index.html"
if [ ! -f "$INDEX_HTML" ]; then
  die "index.html not found in build output: $INDEX_HTML"
fi

# Prepare injection snippet (safe JSON string)
json_escape() {
  python3 - "$1" <<'PY'
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

# Fallback if python3 not available
if command -v python3 >/dev/null 2>&1; then
  API_JSON=$(json_escape "$API_BASE_URL")
  STATIC_JSON=$(json_escape "$STATIC_PATH_PREFIX")
else
  # minimal escaping: wrap in double quotes and escape existing double quotes and backslashes
  esc_api=$(printf '%s' "$API_BASE_URL" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  API_JSON="\"$esc_api\""
  esc_static=$(printf '%s' "$STATIC_PATH_PREFIX" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  STATIC_JSON="\"$esc_static\""
fi

escape_for_head_inject() {
  if command -v python3 >/dev/null 2>&1; then
    json_escape "$1"
    return 0
  fi
  esc_val=$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  echo "\"$esc_val\""
}

# Optional: Ads conversion globals (omit lines when unset)
ADS_ASSIGN=""
if [ -n "${GOOGLE_ADS_CONVERSION_ID:-}" ]; then
  ADS_CONV_JSON=$(escape_for_head_inject "$GOOGLE_ADS_CONVERSION_ID")
  ADS_ASSIGN="${ADS_ASSIGN}window.GOOGLE_ADS_CONVERSION_ID=${ADS_CONV_JSON};"
fi
if [ -n "${GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO:-}" ]; then
  ADS_SEND_JSON=$(escape_for_head_inject "$GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO")
  ADS_ASSIGN="${ADS_ASSIGN}window.GOOGLE_ADS_LOGIN_CONVERSION_SEND_TO=${ADS_SEND_JSON};"
fi

INJECT_SNIPPET="<script>window.API_BASE_URL = $API_JSON; window.STATIC_PATH_PREFIX = $STATIC_JSON; ${ADS_ASSIGN}</script>"

# Insert snippet immediately after <head> so prerendered inline <style> blocks cannot swallow it.
RUNTIME_INJECT_AWK='BEGIN { added = 0 }
  !added && tolower($0) ~ /<head[^>]*>/ {
    print
    print snippet
    added = 1
    next
  }
  { print }
  END { if (!added) { print snippet } }'

# Insert snippet into index.html
TMP_INDEX="$(mktemp)"
awk -v snippet="$INJECT_SNIPPET" "$RUNTIME_INJECT_AWK" "$INDEX_HTML" > "$TMP_INDEX"

run mv "$TMP_INDEX" "$INDEX_HTML"

inject_runtime_into_html() {
  local target_html="$1"
  if [ ! -f "$target_html" ]; then
    return 0
  fi
  local tmp_inject
  tmp_inject="$(mktemp)"
  awk -v snippet="$INJECT_SNIPPET" "$RUNTIME_INJECT_AWK" "$target_html" > "$tmp_inject"
  run mv "$tmp_inject" "$target_html"
}

NOINDEX_META_SNIPPET='<meta name="robots" content="noindex">'
NOINDEX_INJECT_AWK='BEGIN { added = 0 }
  !added && tolower($0) ~ /<head[^>]*>/ {
    print
    print snippet
    added = 1
    next
  }
  { print }
  END { if (!added) { print snippet } }'

inject_noindex_into_html() {
  local target_html="$1"
  if [ ! -f "$target_html" ]; then
    return 0
  fi
  local tmp_inject
  tmp_inject="$(mktemp)"
  awk -v snippet="$NOINDEX_META_SNIPPET" "$NOINDEX_INJECT_AWK" "$target_html" > "$tmp_inject"
  run mv "$tmp_inject" "$target_html"
}

CSR_SHELL_HTML="$BUILD_OUTPUT_DIR/index.csr.html"
if [ ! -f "$CSR_SHELL_HTML" ]; then
  CSR_SHELL_HTML="$INDEX_HTML"
else
  inject_runtime_into_html "$CSR_SHELL_HTML"
fi

PRERENDER_SHELL_PATHS=(
  about contact privacy terms
  "public-plans/new"
  entry-schedule
)
readarray -t ENTRY_SCHEDULE_CROP_SHELL_PATHS < <(
  node --input-type=module -e "import { entryScheduleCropPrerenderPaths } from './frontend/scripts/entry-schedule-prerender-catalog.mjs'; console.log(entryScheduleCropPrerenderPaths().join('\n'))"
)
PRERENDER_SHELL_PATHS+=( "${ENTRY_SCHEDULE_CROP_SHELL_PATHS[@]}" )
CSR_ONLY_SHELL_PATHS=(
  login
  "public-plans/select-crop"
  "public-plans/optimizing"
  "public-plans/results"
)
NOINDEX_CSR_SHELL_PATHS=(
  login
)

for shell_path in "${PRERENDER_SHELL_PATHS[@]}"; do
  prerender_file="$BUILD_OUTPUT_DIR/$STATIC_PATH_PREFIX/$shell_path/index.html"
  if [ -f "$prerender_file" ]; then
    inject_runtime_into_html "$prerender_file"
  fi
done

# Classic EXTERNAL LB does not return HTTP 200 for urlRewrite SPA fallback alone.
# Mirror HTML at public client-route object paths so GCS serves 200 directly.
# Prerendered public routes use build-time SSG HTML; CSR-only routes use index.csr.html.
for shell_path in "${PRERENDER_SHELL_PATHS[@]}"; do
  shell_target="$BUILD_OUTPUT_DIR/$shell_path"
  prerender_file="$BUILD_OUTPUT_DIR/$STATIC_PATH_PREFIX/$shell_path/index.html"
  run mkdir -p "$(dirname "$shell_target")"
  if [ -f "$prerender_file" ]; then
    if [ -d "$shell_target" ]; then
      tmp_prerender="$(mktemp)"
      run cp "$prerender_file" "$tmp_prerender"
      run rm -rf "$shell_target"
      run cp "$tmp_prerender" "$shell_target"
      run rm -f "$tmp_prerender"
    else
      run cp "$prerender_file" "$shell_target"
    fi
  else
    info "Prerender missing for /$shell_path — falling back to CSR shell"
    if [ -d "$shell_target" ]; then
      run rm -rf "$shell_target"
    fi
    run cp "$CSR_SHELL_HTML" "$shell_target"
  fi
done

for shell_path in "${CSR_ONLY_SHELL_PATHS[@]}"; do
  shell_target="$BUILD_OUTPUT_DIR/$shell_path"
  run mkdir -p "$(dirname "$shell_target")"
  if [ -d "$shell_target" ]; then
    run rm -rf "$shell_target"
  fi
  run cp "$CSR_SHELL_HTML" "$shell_target"
  for noindex_path in "${NOINDEX_CSR_SHELL_PATHS[@]}"; do
    if [ "$shell_path" = "$noindex_path" ]; then
      inject_noindex_into_html "$shell_target"
      break
    fi
  done
done

SPA_SHELL_PATHS=( "${PRERENDER_SHELL_PATHS[@]}" "${CSR_ONLY_SHELL_PATHS[@]}" )

# Sync to GCS bucket
GCS_TARGET="gs://$BUCKET_NAME"
info "Syncing to $GCS_TARGET"
# Use rsync: delete removed files (-d), recursive (-r), multithreaded via -m
run gsutil -m rsync -r -d "$BUILD_OUTPUT_DIR" "$GCS_TARGET"

# Set cache-control metadata
info "Setting Cache-Control metadata"
# index.html -> no-cache
run gsutil setmeta -h "Cache-Control: no-cache, max-age=0, must-revalidate" "$GCS_TARGET/index.html"
# SEO shell files — always revalidate (do not set gsutil web -e index.html; breaks SPA HTTP status)
for seo_object in robots.txt sitemap.xml 404.html; do
  if gsutil -q stat "$GCS_TARGET/$seo_object" 2>/dev/null; then
    run gsutil setmeta -h "Cache-Control: no-cache, max-age=0, must-revalidate" "$GCS_TARGET/$seo_object"
  fi
done
# SPA shell mirrors (extensionless objects) — text/html + no-cache
for shell_path in "${SPA_SHELL_PATHS[@]}"; do
  object="$GCS_TARGET/$shell_path"
  if gsutil -q stat "$object" 2>/dev/null; then
    run gsutil setmeta -h "Content-Type:text/html" -h "Cache-Control: no-cache, max-age=0, must-revalidate" "$object"
  fi
done

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

# Research static site (agrr-research-backend) — same gcloud ADC as frontend deploy.
# SYNC_RESEARCH=0 to skip. Default: on for production only.
SYNC_RESEARCH="${SYNC_RESEARCH:-}"
if [ -z "$SYNC_RESEARCH" ]; then
  if [ "$ENV" = "production" ]; then
    SYNC_RESEARCH=1
  else
    SYNC_RESEARCH=0
  fi
fi
if [ "$SYNC_RESEARCH" = "1" ]; then
  RESEARCH_SYNC_SCRIPT="$ROOT_DIR/.cursor/skills/research-tools/scripts/sync-research-gcs.sh"
  if [ ! -x "$RESEARCH_SYNC_SCRIPT" ]; then
    die "Research sync script not found or not executable: $RESEARCH_SYNC_SCRIPT"
  fi
  info "Syncing research assets (public/research → agrr-research-backend)"
  if [ "${DRY_RUN}" = "1" ]; then
    info "[DRY-RUN] PROJECT_ID=$PROJECT_ID FRONTEND_BUCKET=$BUCKET_NAME $RESEARCH_SYNC_SCRIPT"
  else
    PROJECT_ID="$PROJECT_ID" FRONTEND_BUCKET="$BUCKET_NAME" "$RESEARCH_SYNC_SCRIPT"
  fi
fi

# CDN invalidation
if [ -n "${URL_MAP_NAME:-}" ]; then
  info "Invalidating CDN cache via URL map: $URL_MAP_NAME"
  if gcloud compute url-maps describe "$URL_MAP_NAME" --global --project "$PROJECT_ID" >/dev/null 2>&1; then
    run gcloud compute url-maps invalidate-cdn-cache "$URL_MAP_NAME" --path "/*" --project "$PROJECT_ID"
  else
    info "URL map '$URL_MAP_NAME' not found; skipping CDN invalidation."
  fi
else
  info "No URL_MAP_NAME provided; skipping CDN invalidation. If you use Cloud CDN, consider setting URL_MAP_NAME to run invalidate-cdn-cache."
fi

info "Deployment completed for env='$ENV' to bucket='$BUCKET_NAME'."

