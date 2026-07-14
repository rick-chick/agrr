#!/usr/bin/env bash
# P8.6: Ruby Rails tests removed. Delegates to R4 contract runner.
set -e
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
exec "${ROOT}/scripts/run-rust-contract-tests.sh" "$@"
