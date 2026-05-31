#!/usr/bin/env bash
# Alias for ./scripts/dev-rust-stack.sh (E2E 用の旧名。新規は dev-rust-stack を使う)
exec "$(cd "$(dirname "$0")" && pwd)/dev-rust-stack.sh" "$@"
