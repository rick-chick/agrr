#!/usr/bin/env bash
set -euo pipefail

# リポジトリルート（本スクリプトは scripts/ 直下を想定）
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER_DIR="$ROOT/scripts/clean-architecture-workflow-agent-loop"

if [[ ! -d "$RUNNER_DIR" ]]; then
  echo "runner ディレクトリが見つかりません: $RUNNER_DIR" >&2
  exit 1
fi

cd "$RUNNER_DIR"
if [[ ! -d node_modules ]]; then
  npm install
fi

exec node run.mjs --cwd "$ROOT" "$@"
