# Cloud Run 本番環境での SolidQueue 動作確認手順書

## 1. Cloud Run ログからの ActiveJob ログ抽出

### 1.1 ActiveJob の Enqueue ログ抽出

```bash
# サービス名とリージョンを指定（.env.gcp から取得）
PROJECT_ID="your-project-id"
REGION="asia-northeast1"
SERVICE_NAME="agrr-production"

# Enqueue ログを抽出（過去1時間）
gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   textPayload=~\"Enqueued\" OR jsonPayload.message=~\"Enqueued\"" \
  --project=${PROJECT_ID} \
  --limit=100 \
  --format=json \
  --freshness=1h

# より詳細なフィルタ（ActiveJob クラス名を含む）
gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   (textPayload=~\"Enqueued.*Job\" OR jsonPayload.message=~\"Enqueued.*Job\")" \
  --project=${PROJECT_ID} \
  --limit=100 \
  --format=json \
  --freshness=1h
```

### 1.2 Performing ログ抽出（ジョブ実行ログ）

```bash
# Performing ログを抽出
gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   (textPayload=~\"Performing\" OR jsonPayload.message=~\"Performing\")" \
  --project=${PROJECT_ID} \
  --limit=100 \
  --format=json \
  --freshness=1h

# SolidQueue 関連のログも抽出
gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   (textPayload=~\"solid_queue\" OR jsonPayload.message=~\"solid_queue\" OR \
    textPayload=~\"Solid Queue\" OR jsonPayload.message=~\"Solid Queue\")" \
  --project=${PROJECT_ID} \
  --limit=100 \
  --format=json \
  --freshness=1h
```

### 1.3 ログフィルタ例（時間範囲指定）

```bash
# 特定の時間範囲でログを抽出
START_TIME="2026-02-04T00:00:00Z"
END_TIME="2026-02-04T23:59:59Z"

gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   timestamp>=\"${START_TIME}\" AND timestamp<=\"${END_TIME}\" AND \
   (textPayload=~\"Enqueued|Performing\" OR jsonPayload.message=~\"Enqueued|Performing\")" \
  --project=${PROJECT_ID} \
  --limit=1000 \
  --format=json
```

## 2. GCS 上の Litestream レプリカとローカル復元データベースの比較

### 2.1 GCS からデータベースを復元

```bash
# 環境変数の設定
GCS_BUCKET="your-gcs-bucket-name"
PROJECT_ID="your-project-id"

# GCS から最新のレプリカをダウンロード
gsutil cp gs://${GCS_BUCKET}/production/queue.sqlite3 ./production_queue_from_gcs.sqlite3

# または、Litestream を使って復元（推奨）
litestream restore -config config/litestream.yml -o ./production_queue_from_gcs.sqlite3 /tmp/production_queue.sqlite3
```

### 2.2 ファイルサイズの比較

```bash
# ファイルサイズを比較
ls -lh ./production_queue_from_gcs.sqlite3
ls -lh /tmp/production_queue.sqlite3  # Cloud Run コンテナ内の場合

# バイト単位で比較
GCS_SIZE=$(stat -f%z ./production_queue_from_gcs.sqlite3 2>/dev/null || stat -c%s ./production_queue_from_gcs.sqlite3)
LOCAL_SIZE=$(stat -f%z /tmp/production_queue.sqlite3 2>/dev/null || stat -c%s /tmp/production_queue.sqlite3)
echo "GCS size: ${GCS_SIZE} bytes"
echo "Local size: ${LOCAL_SIZE} bytes"
echo "Difference: $((LOCAL_SIZE - GCS_SIZE)) bytes"
```

### 2.3 SQLite PRAGMA による比較

```bash
# 両方のデータベースで PRAGMA を実行して比較
echo "=== GCS レプリカ ==="
sqlite3 ./production_queue_from_gcs.sqlite3 <<EOF
PRAGMA integrity_check;
PRAGMA journal_mode;
PRAGMA synchronous;
PRAGMA wal_checkpoint(TRUNCATE);
PRAGMA page_count;
PRAGMA page_size;
PRAGMA freelist_count;
EOF

echo "=== ローカル復元版 ==="
sqlite3 /tmp/production_queue.sqlite3 <<EOF
PRAGMA integrity_check;
PRAGMA journal_mode;
PRAGMA synchronous;
PRAGMA wal_checkpoint(TRUNCATE);
PRAGMA page_count;
PRAGMA page_size;
PRAGMA freelist_count;
EOF
```

### 2.4 データベースダンプの比較

```bash
# ダンプを取得して比較
sqlite3 ./production_queue_from_gcs.sqlite3 .dump > gcs_dump.sql
sqlite3 /tmp/production_queue.sqlite3 .dump > local_dump.sql

# 差分を確認
diff -u gcs_dump.sql local_dump.sql | head -100
```

### 2.5 特定テーブルのクエリ比較

```bash
# ready_executions テーブルの件数と内容を比較
echo "=== GCS レプリカ: ready_executions ==="
sqlite3 ./production_queue_from_gcs.sqlite3 \
  "SELECT COUNT(*) as count FROM solid_queue_ready_executions;"

echo "=== ローカル復元版: ready_executions ==="
sqlite3 /tmp/production_queue.sqlite3 \
  "SELECT COUNT(*) as count FROM solid_queue_ready_executions;"

# 詳細な比較（最新10件）
echo "=== GCS レプリカ: 最新10件 ==="
sqlite3 ./production_queue_from_gcs.sqlite3 \
  "SELECT id, job_id, queue_name, priority, created_at FROM solid_queue_ready_executions ORDER BY id DESC LIMIT 10;"

echo "=== ローカル復元版: 最新10件 ==="
sqlite3 /tmp/production_queue.sqlite3 \
  "SELECT id, job_id, queue_name, priority, created_at FROM solid_queue_ready_executions ORDER BY id DESC LIMIT 10;"
```

## 3. SolidQueue テーブルの状態確認

### 3.1 ready/claimed テーブルの件数確認

```bash
# ready_executions テーブルの件数
sqlite3 /tmp/production_queue.sqlite3 \
  "SELECT COUNT(*) as ready_count FROM solid_queue_ready_executions;"

# claimed_executions テーブルの件数
sqlite3 /tmp/production_queue.sqlite3 \
  "SELECT COUNT(*) as claimed_count FROM solid_queue_claimed_executions;"

# 両方を一度に確認
sqlite3 /tmp/production_queue.sqlite3 <<EOF
SELECT 
  (SELECT COUNT(*) FROM solid_queue_ready_executions) as ready_count,
  (SELECT COUNT(*) FROM solid_queue_claimed_executions) as claimed_count,
  (SELECT COUNT(*) FROM solid_queue_jobs WHERE finished_at IS NULL) as active_jobs,
  (SELECT COUNT(*) FROM solid_queue_failed_executions) as failed_count;
EOF
```

### 3.2 キュー別の状態確認

```bash
# キュー名別の ready ジョブ数
sqlite3 /tmp/production_queue.sqlite3 \
  "SELECT queue_name, COUNT(*) as count FROM solid_queue_ready_executions GROUP BY queue_name ORDER BY count DESC;"

# キュー名別の claimed ジョブ数
sqlite3 /tmp/production_queue.sqlite3 \
  "SELECT queue_name, COUNT(*) as count FROM solid_queue_claimed_executions GROUP BY queue_name ORDER BY count DESC;"
```

### 3.3 WAL 状態の確認

```bash
# WAL ファイルの存在確認
ls -lh /tmp/production_queue.sqlite3-wal 2>/dev/null || echo "WAL file not found"

# WAL モードの確認
sqlite3 /tmp/production_queue.sqlite3 "PRAGMA journal_mode;"

# WAL チェックポイントの実行
sqlite3 /tmp/production_queue.sqlite3 "PRAGMA wal_checkpoint(TRUNCATE);"

# WAL ファイルサイズの確認
sqlite3 /tmp/production_queue.sqlite3 <<EOF
PRAGMA wal_checkpoint;
SELECT 
  (SELECT page_count FROM pragma_wal_checkpoint) as checkpointed_pages,
  (SELECT page_count FROM pragma_wal) as wal_pages;
EOF

# 整合性チェック
sqlite3 /tmp/production_queue.sqlite3 "PRAGMA integrity_check;"

# より詳細な整合性チェック（時間がかかる場合あり）
sqlite3 /tmp/production_queue.sqlite3 "PRAGMA quick_check;"
```

### 3.4 SolidQueue プロセスの状態確認

```bash
# solid_queue_processes テーブルから worker プロセス情報を取得
sqlite3 /tmp/production_queue.sqlite3 <<EOF
SELECT 
  id,
  name,
  hostname,
  pid,
  supervisor_id,
  last_heartbeat_at,
  created_at
FROM solid_queue_processes
ORDER BY last_heartbeat_at DESC;
EOF
```

## 4. SolidQueue Worker プロセスの確認

### 4.1 プロセス確認コマンド

```bash
# Cloud Run コンテナ内で実行する場合
# ps コマンドで SolidQueue worker プロセスを確認
ps aux | grep -i "solid_queue\|rails.*solid_queue"

# より詳細な確認
ps aux | grep -E "solid_queue|rails" | grep -v grep

# PID ファイルの確認（存在する場合）
cat /tmp/solid_queue.pid 2>/dev/null || echo "PID file not found"
```

### 4.2 起動ログの確認

Cloud Run のログから以下のキーワードを確認:

```bash
# SolidQueue worker 起動ログを抽出
gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   (textPayload=~\"Solid Queue worker started\" OR \
    textPayload=~\"Step 3.4\" OR \
    textPayload=~\"solid_queue:start\")" \
  --project=${PROJECT_ID} \
  --limit=50 \
  --format=json \
  --freshness=24h
```

### 4.3 確認すべき起動時のログキーワード

以下のキーワードがログに含まれていることを確認:

1. **起動開始**
   - `"Step 3.4: Starting Solid Queue worker..."`
   - `"✓ Solid Queue worker started (PID: ...)"`+

2. **初期化完了**
   - `"Waiting ${SOLID_QUEUE_BOOT_DELAY}s for Solid Queue worker to initialize..."`
   - （デフォルト3秒待機後）

3. **エラーがないこと**
   - `"ERROR"` や `"Failed"` が含まれていないこと

4. **データベース準備完了**
   - `"✓ Queue, cache, and cable database migrations completed"`
   - `"✓ All database files verified"`

### 4.4 システムログからの確認

```bash
# Cloud Run のシステムログからプロセス起動を確認
gcloud logging read \
  "resource.type=cloud_run_revision AND \
   resource.labels.service_name=${SERVICE_NAME} AND \
   resource.labels.location=${REGION} AND \
   severity>=WARNING" \
  --project=${PROJECT_ID} \
  --limit=100 \
  --format=json \
  --freshness=1h
```

## 5. トラブルシュートチェックリスト（優先度順）

### 優先度: 高（即座に確認）

- [ ] **SolidQueue worker プロセスが起動しているか**
  ```bash
  # Cloud Run ログで確認
  gcloud logging read "resource.type=cloud_run_revision AND textPayload=~'Solid Queue worker started'" --limit=10
  ```

- [ ] **データベースファイルが存在するか**
  ```bash
  # ログで確認
  gcloud logging read "resource.type=cloud_run_revision AND textPayload=~'All database files verified'" --limit=10
  ```

- [ ] **マイグレーションが完了しているか**
  ```bash
  # ログで確認
  gcloud logging read "resource.type=cloud_run_revision AND textPayload=~'Queue.*database migrations completed'" --limit=10
  ```

- [ ] **WAL モードが有効か**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 "PRAGMA journal_mode;"
  # 期待値: wal
  ```

### 優先度: 中（問題発生時に確認）

- [ ] **ready_executions テーブルにジョブが溜まっていないか**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 "SELECT COUNT(*) FROM solid_queue_ready_executions;"
  ```

- [ ] **claimed_executions テーブルに長時間滞留しているジョブがないか**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 \
    "SELECT COUNT(*) FROM solid_queue_claimed_executions WHERE created_at < datetime('now', '-1 hour');"
  ```

- [ ] **failed_executions テーブルに失敗ジョブがないか**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 "SELECT COUNT(*) FROM solid_queue_failed_executions;"
  ```

- [ ] **データベースの整合性に問題がないか**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 "PRAGMA integrity_check;"
  # 期待値: ok
  ```

- [ ] **GCS レプリカとローカルデータベースの同期状態**
  ```bash
  # ファイルサイズと最終更新時刻を比較
  gsutil stat gs://${GCS_BUCKET}/production/queue.sqlite3
  ```

### 優先度: 低（定期確認）

- [ ] **Litestream レプリケーションが正常に動作しているか**
  ```bash
  # Cloud Run ログで確認
  gcloud logging read "resource.type=cloud_run_revision AND textPayload=~'Litestream'" --limit=50
  ```

- [ ] **SolidQueue worker のハートビートが更新されているか**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 \
    "SELECT name, last_heartbeat_at FROM solid_queue_processes WHERE last_heartbeat_at > datetime('now', '-5 minutes');"
  ```

- [ ] **WAL ファイルが適切にチェックポイントされているか**
  ```bash
  sqlite3 /tmp/production_queue.sqlite3 "PRAGMA wal_checkpoint(TRUNCATE);"
  ```

## 6. 参考情報

### 6.1 関連ファイルパス

- 起動スクリプト: `/app/scripts/start_app.sh`
- データベースファイル: `/tmp/production_queue.sqlite3`
- Litestream 設定: `/etc/litestream.yml`
- SolidQueue 設定: `config/queue.yml`

### 6.2 環境変数

- `SOLID_QUEUE_BOOT_DELAY`: SolidQueue worker の初期化待ち時間（デフォルト: 3秒）
- `QUEUE_MIGRATION_TIMEOUT`: キューDBマイグレーションのタイムアウト（デフォルト: 120秒）
- `JOB_CONCURRENCY`: SolidQueue worker のプロセス数（デフォルト: 1）

### 6.3 ログレベル

本番環境のログレベルは `RAILS_LOG_LEVEL` 環境変数で制御（デフォルト: `info`）。より詳細なログが必要な場合は `debug` に設定。

---

このドキュメントは、`scripts/start_app.sh` と `Dockerfile.production` の実装に基づいて作成されています。

*** End Patch

