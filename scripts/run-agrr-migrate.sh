#!/usr/bin/env bash
# Run agrr-migrate (release binary, or cargo fallback).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export AGRR_APP_ROOT="${AGRR_APP_ROOT:-$ROOT}"

if command -v agrr-migrate >/dev/null 2>&1; then
  exec agrr-migrate "$@"
fi
if [ -x "${ROOT}/target/release/agrr-migrate" ]; then
  exec "${ROOT}/target/release/agrr-migrate" "$@"
fi
exec cargo run --manifest-path "${ROOT}/Cargo.toml" -p agrr-migrate -- "$@"
