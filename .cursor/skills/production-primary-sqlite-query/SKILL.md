---
name: production-primary-sqlite-query
description: Restores the production primary SQLite database from the GCS Litestream replica and runs sqlite3 queries or built-in user counts. Use when the user asks for production DB stats, user counts, or read-only inspection of primary data without hitting Cloud Run.
---

# Production primary SQLite（GCS レプリカ）の照会

本番のプライマリ DB は Cloud Run 上の SQLite（`/tmp/production.sqlite3`）で、Litestream で GCS に複製される。直接本番コンテナに入らず、**GCS レプリカから復元**して読み取り専用で調べる。

## 前提

- GCP 認証: Application Default Credentials（例: `gcloud auth application-default login`）。`gsutil ls gs://agrr-production-db/...` が通ること。
- 依存: `curl`, `sqlite3`, `dpkg-deb`（Litestream の deb 展開用）。
- **Litestream のメジャーは `Dockerfile.production` と一致させる**（現在 v0.3.13）。`type: gcs` を使う。スクリプト [scripts/query_production_primary_sqlite.sh](scripts/query_production_primary_sqlite.sh) は deb から同じバージョンをキャッシュする。

## 手順（エージェント）

リポジトリルートをカレントにして実行する（スキル配下のスクリプト）。

1. 集計や件数確認が目的なら、まずスクリプトを実行する。

```bash
./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh
```

引数なしのときは `users` の件数（全行 / 登録 / 匿名）を表示する。

2. 任意 SQL は第 1 引数で渡す。

```bash
./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh "SELECT id, email FROM users LIMIT 10;"
```

3. 復元ファイルのパスだけ取得して手で調べる場合（一時ディレクトリはプロセス終了まで残る）。復元ログは stderr のみ（`DBPATH=$(...)` でパスだけ取れる）。

```bash
DBPATH=$(KEEP_DB=1 ./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh)
sqlite3 -header -line "$DBPATH" \
  "SELECT id, email, subject, message FROM contact_messages ORDER BY created_at DESC LIMIT 20;"
```

4. バケットやレプリカパスを変える場合は環境変数（`GCS_BUCKET`, `LITESTREAM_REPLICA`）を参照。

## 注意

- レプリカは同期間隔の分だけ**本番ライブより遅れる**可能性がある（`config/litestream.yml` の `sync-interval`）。
- **書き込み・本番データの変更は行わない**。読み取り専用の調査・件数確認用。
- Litestream v0.5 系 CLI はレプリカ表記が異なる（`gcs` と `gs` など）。**このプロジェクトの復元は v0.3.13 に合わせる**こと。スクリプト外で手動実行する場合は混在させない。
