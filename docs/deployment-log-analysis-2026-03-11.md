# GCP デプロイ・運用ログ分析レポート (2026-03-11)

## 調査サマリ

| 項目 | 結果 |
|------|------|
| **Cloud Run サービス** | Ready（agrr-production-00135-6cz） |
| **主なエラー** | SQLite3::BusyException: database is locked |
| **発生箇所** | SolidQueue Worker の production_queue.sqlite3 アクセス |
| **HTTP WARNING** | 401 + 長レイテンシ（コールドスタート起因） |

---

## 1. 主なエラー: SQLite database is locked

### エラー内容

```
SQLite3::BusyException: database is locked (ActiveRecord::StatementTimeout)
```

**発生日時**: 2026-03-11 01:31:41 UTC  
**発生箇所**: SolidQueue Worker の `claim_executions`（ready_execution のロック取得）

### スタックトレース概要

```
solid_queue/worker.rb:40:in `claim_executions'
  → ready_execution.rb:26:in `select_and_lock'
  → activerecord/transaction
  → sqlite3/database_statements.rb:100:in `step'
```

SolidQueue Worker がジョブ取得のため `production_queue.sqlite3` にトランザクションでアクセスした際、他のプロセスが DB を占有しており、`SQLITE_BUSY_TIMEOUT_MS`（デフォルト 20 秒）を超えて `SQLite3::BusyException` が発生している。

### 競合要因（Litestream 除外後）

`production_queue.sqlite3` には以下が同時アクセスする（Litestream は 2026-03-11 に除外済み）：

| プロセス | 役割 | アクセス種別 |
|----------|------|--------------|
| Puma | ジョブ enqueue 時 | 書込 |
| SolidQueue（Dispatcher + Worker） | ジョブ投入・取得・実行 | 読書 |

SQLite は単一ライターのため、2 プロセスによる書き込み競合でロックが発生する。

### 現状設定（2026-03-11 実施後）

- `config/database.yml`: `timeout: <%= ENV.fetch("SQLITE_BUSY_TIMEOUT_MS", 20000) %>`
- `.env.gcp`: `SQLITE_BUSY_TIMEOUT_MS=60000`（60 秒）
- `config/queue.yml`: `polling_interval: 2`、`threads: 1`
- `SOLID_QUEUE_IN_PUMA=true`（Puma プラグインで SolidQueue 起動）

---

## 2. SolidQueue プロセスの再起動ループ

ログ上の挙動：

```
SolidQueue-1.2.1 Replaced terminated Worker (13399.5ms)  pid: 136
SolidQueue-1.2.1 Replaced terminated Dispatcher (9200.7ms)  pid: 133
SolidQueue-1.2.1 Shutdown Worker (68700.3ms)  pid: 136
```

Worker / Dispatcher が `database is locked` でクラッシュすると、SolidQueue Supervisor が自動再起動している。  
再起動のたびに DB アクセスが再開され、またロック待ちになる可能性がある。

---

## 3. HTTP WARNING ログ（401 + 長レイテンシ）

| 日時 | リクエスト | レイテンシ | ステータス |
|------|------------|------------|------------|
| 2026-03-11 01:12 | GET /api/v1/auth/me | **60 秒** | 401 |
| 2026-03-11 00:11 | GET /api/v1/auth/me | 0.01 秒 | 401 |
| 2026-03-11 00:08 | GET /api/v1/auth/me | **240 秒** | 401 |
| 2026-03-10 20:58 | GET /api/v1/auth/me | **240 秒** | 401 |
| 2026-03-10 16:38 | GET /api/v1/auth/me | **240 秒** | 401 |

- **401**: 認証なしでの `/api/v1/auth/me` は想定どおりの応答
- **240 秒**: コールドスタート待ち（スケール 0 → 1）が原因と判断
- インスタンス起動後は 0.01 秒など短い応答になっており、アプリ本体の処理は問題なし

---

## 4. デプロイパイプライン

- **Cloud Build API**: 無効（`cloudbuild.googleapis.com`）
- **デプロイ方式**: ローカルで `docker build` → Artifact Registry へ push → `gcloud run deploy`
- **Cloud Build ログ**: 利用していないため、別途デプロイログ取得が必要

---

## 5. 推奨対応

### 5.1 database is locked 対策（実施済み 2026-03-11）

**1. キュー DB を Litestream のレプリケーション対象から除外**（`config/litestream.yml`）

- **理由**: Litestream の checkpoint と SolidQueue が同じ SQLite に同時アクセスしてロック競合していた
- **効果**: Litestream 起因の競合を解消。Puma と SolidQueue の 2 プロセス競合は残る

**2. SQLITE_BUSY_TIMEOUT_MS の延長**

- `.env.gcp`: `SQLITE_BUSY_TIMEOUT_MS=60000`（20 秒 → 60 秒）
- ロック待ち時間を延長し、競合時の失敗を減らす

**3. polling_interval の増加**

- `config/queue.yml`: Worker の `polling_interval` を 0.1 秒 → 2 秒に変更
- DB アクセス頻度を下げて競合確率を低減

**4. SOLID_QUEUE_IN_PUMA による起動構成の統一**

- SolidQueue を Puma プラグインで起動し、`solid_queue:start` を廃止
- プロセスライフサイクルを Puma に集約。**注意**: プラグインは内部で fork するため、2 プロセス競合は解消されない

**5. SOLID_QUEUE_BOOT_DELAY**

- `gcp-deploy.sh` で環境変数に追加済み（`.env.gcp` の設定が Cloud Run に渡る）

### 5.3 コールドスタート 240 秒対策（優先度中）

- 現状コールドスタートは 14〜22 秒程度に改善済み（`docs/cold-start-analysis-2026-03-11.md`）
- 240 秒は Cloud Run のリクエストタイムアウトや、スケール 0 時の初回インスタンス起動待ちの可能性
- `MIN_INSTANCES=1` にするとコールドスタートは回避できるが、常時課金となる

### 5.4 監視の継続

- `database is locked` の発生頻度
- SolidQueue Worker/Dispatcher の再起動回数
- コールドスタート時のリクエストレイテンシ

---

## 6. ログ取得コマンド（参考）

```bash
# 直近の ERROR/WARNING
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND severity>=WARNING' \
  --project=agrr-475323 --limit=50 --format="table(timestamp,severity,textPayload)" --freshness=24h

# database is locked 関連
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND textPayload=~"database is locked"' \
  --project=agrr-475323 --limit=20 --freshness=7d

# SolidQueue 再起動
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND textPayload=~"Replaced terminated"' \
  --project=agrr-475323 --limit=20 --freshness=7d
```
