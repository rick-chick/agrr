# Source from shell profile on Cloud Agent boots (see cloud-gh-auth.sh).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="${ROOT}/.cursor/bin:${PATH}"
