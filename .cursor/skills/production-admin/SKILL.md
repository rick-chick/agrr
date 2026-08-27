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

### トークンローテーション

1. 新しいランダムトークンを生成（例: `openssl rand -hex 32`）
2. GCP Secret Manager / Cloud Run の `AGRR_BACKDOOR_TOKEN` を新値に更新してデプロイ
3. ローカル `.env.gcp` を新値に更新
4. 旧トークンを使っていた端末・CI シークレットから削除
5. Cloud Logging で `backdoor_auth_failure` / `invalid_token` が旧トークン由来でないことを確認

### トークン漏洩時

1. **即時ローテーション**（上記手順）— 調査完了を待たず実施
2. Cloud Logging で `event_type=backdoor_operation` を検索し、漏洩後の不正利用有無を確認（トークン本体はログに出ない）
3. 疑わしい `user_create` / `user_update` / `db_clear` があれば本番 DB を [`production-primary-sqlite-query`](../production-primary-sqlite-query/SKILL.md) で調査
4. 必要に応じて影響ユーザー・権限変更を巻き戻し

### 本番 `db/clear`（break-glass）

本番では `POST /api/v1/backdoor/db/clear` は **既定で無効**。全データ削除が必要な場合のみ:

1. Cloud Run に一時的に `AGRR_BACKDOOR_ALLOW_DB_CLEAR=1` を設定してデプロイ
2. 作業完了後 **必ず** 当該 env を削除して再デプロイ
3. 操作は `backdoor_operation` 監査ログ（`db_clear:success` 等）に記録される

予測チェーン調査との併用: [`prediction-investigation`](../prediction-investigation/SKILL.md)、本番 DB: [`production-primary-sqlite-query`](../production-primary-sqlite-query/SKILL.md)。

**注意**: 本番に直接影響する操作。実行前に意図を確認する。
