#!/bin/bash

# 本番環境のcacheとcableデータベースのスキーマを取得するスクリプト

set -e

GCS_BUCKET=${GCS_BUCKET:-agrr-production-db}
TMP_DIR=/tmp/production_schemas_$$
mkdir -p "$TMP_DIR"

echo "=== 本番環境のデータベーススキーマ取得 ==="
echo "GCS Bucket: $GCS_BUCKET"
echo ""

# Litestream設定ファイルを作成
LITESTREAM_CONFIG="$TMP_DIR/litestream.yml"
cat > "$LITESTREAM_CONFIG" <<EOF
dbs:
  - path: $TMP_DIR/production_cache.sqlite3
    replicas:
      - type: gcs
        bucket: $GCS_BUCKET
        path: production_cache.sqlite3
  - path: $TMP_DIR/production_cable.sqlite3
    replicas:
      - type: gcs
        bucket: $GCS_BUCKET
        path: production_cable.sqlite3
EOF

echo "Step 1: GCSからcacheデータベースを復元..."
if litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" "$TMP_DIR/production_cache.sqlite3"; then
    echo "✓ Cache database restored"
else
    echo "⚠ Cache database not found in GCS"
    exit 1
fi

echo ""
echo "Step 2: GCSからcableデータベースを復元..."
if litestream restore -if-replica-exists -config "$LITESTREAM_CONFIG" "$TMP_DIR/production_cable.sqlite3"; then
    echo "✓ Cable database restored"
else
    echo "⚠ Cable database not found in GCS"
    exit 1
fi

echo ""
echo "=== Cache Database Schema ==="
sqlite3 "$TMP_DIR/production_cache.sqlite3" ".schema"

echo ""
echo "=== Cable Database Schema ==="
sqlite3 "$TMP_DIR/production_cable.sqlite3" ".schema"

# クリーンアップ
rm -rf "$TMP_DIR"
echo ""
echo "✓ 完了"

