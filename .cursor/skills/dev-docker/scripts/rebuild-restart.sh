#!/usr/bin/env bash
# agrr-server イメージを再ビルドし、コンテナを再作成してヘルスチェック完了まで待つ。
# Rust API（crates/*）はイメージに焼き込まれるため、ソース変更後は本スクリプトが必須。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

echo "=== Rebuilding agrr-server image ==="
docker compose build agrr-server "$@"

echo "=== Recreating agrr-server container ==="
docker compose up -d --force-recreate --no-deps agrr-server

echo "=== Waiting for agrr-server to become healthy ==="
deadline=$((SECONDS + 180))
while (( SECONDS < deadline )); do
  status="$(docker compose ps --status running --format json agrr-server 2>/dev/null | head -1 || true)"
  if [[ -n "$status" ]] && echo "$status" | grep -q '"Health":"healthy"'; then
    echo "=== agrr-server is healthy ==="
    exit 0
  fi
  # fallback: curl from host when health JSON is unavailable
  if curl -sf http://127.0.0.1:8080/up >/dev/null 2>&1; then
    echo "=== agrr-server is up (/up OK) ==="
    exit 0
  fi
  sleep 2
done

echo "ERROR: agrr-server did not become healthy within 180s" >&2
docker compose logs --tail=80 agrr-server >&2 || true
exit 1
