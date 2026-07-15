#!/usr/bin/env bash
# crates/agrr-domain のユニットテスト（cargo test）。Rails / DB 不要。
# 引数は cargo test にそのまま渡す（例: -p agrr-domain -- crop_policy）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

if ! command -v cargo >/dev/null 2>&1; then
  if [ -f "${HOME}/.cargo/env" ]; then
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  fi
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "==> cargo not found. Install Rust (https://rustup.rs) or run in an environment with rust-toolchain.toml."
  exit 1
fi

echo "==> Running Rust domain tests (cargo test -p agrr-domain)..."
cargo test -p agrr-domain "$@"

echo "==> Running agrr-migrate tests..."
cargo test -p agrr-migrate --quiet
