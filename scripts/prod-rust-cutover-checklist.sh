#!/usr/bin/env bash
# Pre-flight checklist for production Rust-only API (level D). Does not mutate GCP.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Local gates"
cargo build -p agrr-server
AGRR_SERVER_CONTRACT_REBUILD=1 COVERAGE=false ./scripts/run-rust-contract-tests.sh

echo "==> Manual GCP (operator)"
cat <<'EOF'
[ ] URL map: all /api/* /cable /auth/* → rust-backend; no rails API pathRules
[ ] Cloud Run rails-backend traffic 0
[ ] agrr-server revision healthy; /health and /up on Rust
[ ] OAuth login smoke on agrr.net
[ ] Plan create → optimization WS → masters CRUD → save_plan → undo_deletion
EOF

echo "Done (local automated checks only)."
