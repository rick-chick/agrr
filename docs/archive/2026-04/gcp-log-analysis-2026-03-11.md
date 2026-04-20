# GCP ログ分析レポート（2026-03-11）

## 調査サマリ

| 項目 | 結果 |
|------|------|
| **調査範囲** | 直近 2〜3 日間の Cloud Run ログ |
| **現在のリビジョン** | agrr-production-00136-z5c（ACTIVE） |
| **検出したエラー** | 2 種類（起動失敗、実行時クラッシュ） |

---

## 1. エラー 1: 起動プローブ失敗（2026-03-10 05:46）

### 概要

リビジョン `agrr-production-00124-m5n` がスタートアッププローブに失敗し、Cloud Run の `HealthCheckContainerError` によりデプロイがロールバックされた。

### 根本原因

```
SQLite3::SQLException: cannot VACUUM from within a transaction
```

**発生箇所**: マイグレーション `db/migrate/20260310053009_vacuum_after_weather_data_truncate.rb`

Rails のマイグレーションはデフォルトで DDL をトランザクション内で実行する。SQLite は **VACUUM をトランザクション内で実行できない** ため、マイグレーション起動時にクラッシュした。

### スタックトレース

```
db/migrate/20260310053009_vacuum_after_weather_data_truncate.rb:5:in `up'
  → activerecord/migration.rb
  → activerecord/connection_adapters/abstract/transaction.rb (ddl_transaction)
  → sqlite3/database_statements.rb:56:in `execute'
```

### 対応状況

**既に修正済み**: 現行のマイグレーションファイルでは `up` メソッド内の VACUUM 実行を削除し、コメントのみ残している。

```ruby
def up
  # VACUUM はメンテナンス用 rake タスクで実行（起動時のロック競合を避ける）
  # rails db:vacuum で手動実行
end
```

この修正後、00132 以降のデプロイは成功している。

---

## 2. エラー 2: SolidQueue Worker クラッシュ（2026-03-11 01:49）

### 概要

リビジョン `agrr-production-00136-z5c` で SolidQueue Worker がクラッシュし、Supervisor による自動再起動が発生している。

### 根本原因

```
SQLite3::BusyException: database is locked
```

**発生箇所**: SolidQueue Worker の `claim_executions`（ジョブ取得時のトランザクション）

`production_queue.sqlite3` に対する同時アクセスにより、`SQLITE_BUSY_TIMEOUT_MS`（デフォルト 20 秒）を超えてロック取得に失敗している。

### スタックトレース概要

```
solid_queue/worker.rb:40:in `claim_executions'
  → ready_execution.rb:26:in `select_and_lock'
  → activerecord/transaction
  → activerecord/relation.rb:378:in `empty?'  # exists? クエリ実行時
  → sqlite3/database_statements.rb:100:in `step'
```

### 競合要因

| プロセス | 役割 | アクセス種別 |
|----------|------|--------------|
| Litestream | WAL → GCS レプリケーション | 読取 |
| SolidQueue Dispatcher | ジョブ投入・スケジュール | 読書 |
| SolidQueue Worker | ジョブ取得・実行 | 読書（トランザクション） |

起動直後や WAL 書き込み中に、これらの同時アクセスでロック競合が発生する。

### 関連ログ

```
SolidQueue-1.2.1 Replaced terminated Worker (28600.2ms)   pid: 134
SolidQueue-1.2.1 Replaced terminated Dispatcher (36800.3ms)  pid: 131
```

Worker / Dispatcher がクラッシュするたびに Supervisor が再起動し、運用上は復旧しているが、ロック競合は継続的に発生する可能性がある。

---

## 3. その他のログ状況

### 正常動作ログ

- Litestream: WAL セグメントの GCS への書き込み（例: `wal segment written`, `write wal segment`）
- SolidQueue: Worker / Dispatcher の再起動・置換（クラッシュ後の復旧）

### 3/10 の ERROR ログについて

`severity=ERROR` で記録されていた 2 件は、Cloud Run の監査ログ（`HealthCheckContainerError`）であり、上記の VACUUM マイグレーション失敗に対応する。

---

## 4. 対応状況と推奨

### 4.1 根本対策（実施済み 2026-03-11）

**キュー DB を Litestream のレプリケーション対象から除外**（`config/litestream.yml`）

- Litestream の checkpoint と SolidQueue が同じ SQLite に同時アクセスしていたため、ロック競合の根本原因であった
- キューは一時データのため、再起動で空になっても recurring スケジュールから再投入される
- デプロイ後に `database is locked` の解消を確認

### 4.2 従来案（必要に応じて）

キュー除外後も競合が残る場合のみ検討：

1. **SQLITE_BUSY_TIMEOUT_MS の延長**（`.env.gcp`）
2. **SOLID_QUEUE_BOOT_DELAY** の短縮（20 秒 → 1〜5 秒を検討）

### 4.3 VACUUM 実行方法

マイグレーションでは VACUUM を実行せず、必要に応じて手動で実行する：

```bash
bundle exec rails db:vacuum  # または適切な rake タスク
```

トランザクション外で単独実行する必要がある。

---

## 5. ログ取得コマンド（参考）

```bash
# 直近の ERROR
gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=agrr-production AND severity>=ERROR' \
  --project=agrr-475323 --limit=20 --format=json

# database is locked 関連
gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=agrr-production AND textPayload=~"database is locked"' \
  --project=agrr-475323 --limit=20 --freshness=7d

# SolidQueue 再起動
gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=agrr-production AND textPayload=~"Replaced terminated"' \
  --project=agrr-475323 --limit=20 --freshness=7d
```
