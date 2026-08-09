#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node --input-type=module -e "
import { runArchitectureGuardCli } from './scripts/run-architecture-guard-lib.mjs';
process.exit(runArchitectureGuardCli('${ROOT}'));
"
