#!/usr/bin/env bash
# Alias for ./scripts/dev-rust-stack.sh (旧名)
exec "$(cd "$(dirname "$0")" && pwd)/dev-rust-stack.sh" "$@"
