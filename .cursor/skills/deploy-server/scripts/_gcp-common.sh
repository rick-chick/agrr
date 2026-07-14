# shellcheck shell=bash
# Shared helpers for GCP Cloud Run deploy scripts (sourced, not executed).

_gcp_common_project_root() {
  local script_dir=$1
  if ! PROJECT_ROOT="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)"; then
    echo "ERROR: repository root not found (git rev-parse failed)" >&2
    return 1
  fi
  export PROJECT_ROOT
}

_gcp_load_env_file() {
  local f=$1
  if [ -f "$f" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$f"
    set +a
  fi
}

_gcp_yaml_kv() {
  local key=$1 val=${2:-}
  printf '%s: "%s"\n' "$key" "$(printf '%s' "$val" | sed 's/"/\\"/g')"
}

_gcp_preflight() {
  local require_env_file=$1
  if [ "$require_env_file" = "1" ] && [ ! -f "${PROJECT_ROOT}/.env.gcp" ]; then
    echo "ERROR: ${PROJECT_ROOT}/.env.gcp not found (copy from env.gcp.example)" >&2
    return 1
  fi
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "ERROR: gcloud not found" >&2
    return 1
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found" >&2
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: docker daemon not running" >&2
    return 1
  fi
  if [ "${SKIP_GIT_CHECKS:-0}" != "1" ]; then
    local branch
    branch="$(git -C "$PROJECT_ROOT" branch --show-current)"
    if [ -n "${REQUIRE_BRANCH:-master}" ] && [ "${REQUIRE_BRANCH:-master}" != "$branch" ]; then
      echo "ERROR: on branch '$branch'; expected '${REQUIRE_BRANCH:-master}' (SKIP_GIT_CHECKS=1 to override)" >&2
      return 1
    fi
    if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
      echo "ERROR: uncommitted changes (commit/stash or SKIP_GIT_CHECKS=1)" >&2
      return 1
    fi
  fi
}

_gcp_configure_docker_registry() {
  local region=$1
  gcloud auth configure-docker "${region}-docker.pkg.dev" --quiet
}
