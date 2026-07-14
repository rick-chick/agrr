#!/usr/bin/env bash
# lib/domain のユニットテストのみを実行（Rails / DB を起動しない）。
# 引数は bin/domain-lib-test にそのまま渡す（省略時はデフォルトの純粋ドメインテスト一式）。
set -e
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

echo "==> Running domain-lib tests (no Rails stack, via Docker Compose test profile)..."
docker compose --profile test run --rm \
  -e AGRR_TEST_SCRIPT=1 \
  test bundle exec bin/domain-lib-test "$@"
