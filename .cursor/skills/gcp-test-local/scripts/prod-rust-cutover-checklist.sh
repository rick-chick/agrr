#!/usr/bin/env bash
# Pre-flight checklist for production Rust-only API (level 4). Does not mutate GCP.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  echo "ERROR: repository root not found" >&2
  exit 1
fi
cd "$PROJECT_ROOT"

echo "==> Local gate (re-run before Rust/deploy changes; one script is enough)"
./scripts/p7-code-removal-gate.sh

echo "==> Manual GCP / product smoke — see docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md"
cat <<'EOF'
[x] Local gate p7-code-removal-gate.sh — 2026-06-01 OK (109 contract runs, 0 failures)
[x] agrr-production image is agrr-server (Rust) — observed 20260531-222952
[x] agrr.net /up → 200 plain "ok"; /api/v1/health → Rust JSON; unknown API → 501 api_not_migrated
[x] LB paths /api/* /cable /auth/* /up → rust-backend → agrr-rails-neg → agrr-production (Rust)
[x] URL map backend name rust-backend (2026-05-31; NEG agrr-rails-neg is historical)
[x] P7 code removal: API layer, lib/domain, Solid Cable DB
[x] Prod replica: agrr-migrate schema verify (refinery OK — 2026-05-31)
[x] Prod data: in/us reference crop repair (`20260531130100` / `20260531130200`) — 2026-06-01
[x] Manual smoke sign-off on agrr.net — 2026-06-01 (OAuth, auth/me, plan+WS, masters CRUD, save_plan, undo_deletion)
EOF

echo "Done (local automated checks only)."
