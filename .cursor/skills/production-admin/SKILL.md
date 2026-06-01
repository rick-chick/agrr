# Production Admin Tools

本番環境の運用・調査用スクリプト（LB 経由 API、GCS レプリカ DB、Cloud Run Job 上の agrr CLI）。

## Scripts

| スクリプト | 用途 |
|-----------|------|
| **set_user_admin.sh** | ユーザーを管理者に昇格 |
| **get_production_schemas.sh** | 本番 SQLite スキーマを取得 |
| **check_production_users.sh** | 本番ユーザーリスト |
| **check_production_backdoor.sh** | バックドア API 稼働確認（公開 URL） |
| **run-production-agrr-cli.sh** | 本番と同イメージの Cloud Run Job で `agrr weather` 等（ライブ revision 非接触） |

## Usage

リポジトリルートの `.env.gcp`（`env.gcp.example` から作成）が必要。HTTP API は **ロードバランサ経由の公開 URL**（`ALLOWED_HOSTS` の先頭、または `PRODUCTION_PUBLIC_URL`）。Cloud Run の `*.run.app` は ingress が LB 限定のとき **404**。

```bash
.cursor/skills/production-admin/scripts/set_user_admin.sh <user_id>
.cursor/skills/production-admin/scripts/get_production_schemas.sh
.cursor/skills/production-admin/scripts/check_production_users.sh
.cursor/skills/production-admin/scripts/check_production_backdoor.sh

# agrr CLI（デーモン起動込み・調査用 Job）
.cursor/skills/production-admin/scripts/run-production-agrr-cli.sh weather --preset bhopal-gap
.cursor/skills/production-admin/scripts/run-production-agrr-cli.sh logs
.cursor/skills/production-admin/scripts/run-production-agrr-cli.sh delete-job
```

バックドアトークンは `.env.gcp` の `AGRR_BACKDOOR_TOKEN`（Rails `show_backdoor_token.rb` は P8 削除済み）。

予測チェーン調査との併用: [`prediction-investigation`](../prediction-investigation/SKILL.md)、本番 DB: [`production-primary-sqlite-query`](../production-primary-sqlite-query/SKILL.md)。

⚠️ 本番に直接影響する操作。実行前に意図を確認する。
