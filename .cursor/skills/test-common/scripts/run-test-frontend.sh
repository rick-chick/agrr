#!/usr/bin/env bash
# Frontend（Angular）テストを実行。引数は npm test にそのまま渡す。
set -e
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT/frontend"

# If the caller already passes a --watch flag, trust their choice.
for arg in "$@"; do
  case "$arg" in
    --watch=*|--watch)
      FORCE_DEFAULT_WATCH=false
      break
      ;;
  esac
done

if [ "$FORCE_DEFAULT_WATCH" = false ]; then
  npm test -- "$@"
else
  npm test -- --watch=false "$@"
fi
