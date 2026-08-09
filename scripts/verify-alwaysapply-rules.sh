#!/usr/bin/env bash
# Contract: alwaysApply rules are exactly 4 files, <=80 lines total, CLAUDE.md refs match.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node --test scripts/verify-alwaysapply-rules.test.mjs
