# 開発環境 Litestream 設定の動作確認

## 設定確認結果

### ✅ 設定ファイルの存在確認
- `config/litestream.development.yml` - 存在確認済み
- `config/cache.yml` - development環境で `database: cache` 設定済み
- `config/cable.yml` - development環境で `adapter: solid_cable` 設定済み

### ✅ 環境変数の設定
- `docker-compose.yml` で `GCS_BUCKET_DEV` 環境変数が設定済み
- デフォルト値: `agrr-development-db`

### ✅ データベース分離状況

**本番環境:**
- バケット: `${GCS_BUCKET}` (例: `agrr-production-db`)
- GCSパス: `production/primary.sqlite3`, `production/queue.sqlite3`, `production/cache.sqlite3`, `production/cable.sqlite3`
- ローカルパス: `/tmp/production_*.sqlite3`

**開発環境:**
- バケット: `${GCS_BUCKET_DEV}` (例: `agrr-development-db`)
- GCSパス: `development/primary.sqlite3`, `development/queue.sqlite3`, `development/cache.sqlite3`, `development/cable.sqlite3`
- ローカルパス: `storage/development_*.sqlite3`

### ✅ 起動スクリプトの確認
- `scripts/docker-entrypoint-dev-daemon.sh` - litestream復元とレプリケーション処理が実装済み
- `scripts/docker-entrypoint-dev.sh` - litestream復元とレプリケーション処理が実装済み

## 動作確認手順

### 1. 環境変数の設定

`.env` ファイルまたは環境変数で `GCS_BUCKET_DEV` を設定:

```bash
GCS_BUCKET_DEV=agrr-development-db
```

### 2. Dockerコンテナの起動

```bash
docker compose up web
```

### 3. 確認ポイント

起動ログで以下を確認:

1. **Litestream復元処理**
   ```
   =========================================
   Restoring databases from GCS via Litestream...
   =========================================
   ✓ Main database restored from GCS
   ✓ Queue database restored from GCS
   ✓ Cache database restored from GCS
   ✓ Cable database restored from GCS
   ```

2. **マイグレーション実行**
   ```
   =========================================
   Running migrations for all databases (primary, queue, cache, cable)...
   =========================================
   ```

3. **Litestreamレプリケーション開始**
   ```
   =========================================
   Starting Litestream replication...
   =========================================
   ✓ Litestream started (PID: xxxxx)
   ```

### 4. GCS_BUCKET_DEV未設定の場合

`GCS_BUCKET_DEV` が設定されていない場合、以下のメッセージが表示され、litestreamはスキップされます:

```
⚠ GCS_BUCKET_DEV not set, skipping Litestream restore
```

この場合でも、アプリケーションは通常通り起動します（litestreamなし）。

## トラブルシューティング

### エラー: `_litestream_seq` テーブルが見つからない

このエラーが発生する場合、以下の対処を検討:

1. **データベースファイルを削除して再作成**
   ```bash
   rm storage/development_*.sqlite3
   docker compose up web
   ```

2. **Litestreamの初期化を確認**
   - マイグレーション実行後にlitestreamが開始されることを確認
   - データベースファイルが存在することを確認

3. **ログの確認**
   ```bash
   docker compose logs web | grep -i litestream
   ```

## 本番環境との比較

| 項目 | 本番環境 | 開発環境 |
|------|---------|---------|
| バケット | `GCS_BUCKET` | `GCS_BUCKET_DEV` |
| GCSパスプレフィックス | `production/` | `development/` |
| ローカルパス | `/tmp/production_*.sqlite3` | `storage/development_*.sqlite3` |
| Cache設定 | `database: cache` | `database: cache` |
| Cable設定 | `adapter: solid_cable` | `adapter: solid_cable` |
| 起動スクリプト | `scripts/start_app.sh` | `scripts/docker-entrypoint-dev-daemon.sh` |

## 結論

✅ 設定は正しく実装されています
✅ 本番環境と開発環境は完全に分離されています
✅ `GCS_BUCKET_DEV` を設定することで、開発環境でもlitestreamが動作します

