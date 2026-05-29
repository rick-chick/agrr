#!/usr/bin/env bash
# crates/agrr-domain の lib カバレッジ（llvm-cov）。初回は rustup component add llvm-tools-preview が必要。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v cargo >/dev/null 2>&1; then
  if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  fi
fi

if ! cargo llvm-cov --version >/dev/null 2>&1; then
  echo "==> cargo-llvm-cov not found."
  echo "    Install: cargo install cargo-llvm-cov"
  echo "    Then:    rustup component add llvm-tools-preview"
  exit 1
fi

echo "==> Rust domain coverage (agrr-domain, lib only)..."
cargo llvm-cov -p agrr-domain --lib --summary-only "$@"
