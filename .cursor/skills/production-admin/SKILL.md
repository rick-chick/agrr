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

**注意**: 本番に直接影響する操作。実行前に意図を確認する。

## Backdoor トークン運用（`AGRR_BACKDOOR_TOKEN`）

Backdoor API は `X-Backdoor-Token` ヘッダで認証する。トークン本体は **構造化監査ログに記録しない**（`backdoor_operation` イベントは action/outcome のみ）。

### 定期ローテーション（推奨: 四半期ごと）

1. 新トークンを生成（例: `openssl rand -hex 32`）
2. GCP Secret Manager / Cloud Run の `AGRR_BACKDOOR_TOKEN` を更新し、新 revision をデプロイ
3. ローカル `.env.gcp` の `AGRR_BACKDOOR_TOKEN` を同期
4. `check_production_backdoor.sh` で `GET /api/v1/backdoor/health` が 200 になることを確認
5. 旧トークンを Secret Manager から削除（ロールバック用に 24h 保持してもよい）

### 漏洩疑い・漏洩確認時

1. **即時ローテーション**（上記手順を緊急実施）
2. Cloud Logging で `event_type="backdoor_operation"` を検索し、不審な action/outcome を確認
3. 影響調査: `check_production_users.sh` で管理者昇格の有無を確認
4. 必要に応じて疑わしいユーザーの `admin` を戻す（`set_user_admin.sh` の逆操作は backdoor `PATCH /users/{id}`）
5. インシデント記録を残す（時刻・ローテーション実施・影響範囲）

### 本番での `db/clear` 禁止

`POST /api/v1/backdoor/db/clear` は **本番（`AGRR_ENV=production`）では 403**。全データ削除が必要な場合は break-glass として:

- Litestream レプリカからのリストア: [`production-primary-sqlite-query`](../production-primary-sqlite-query/SKILL.md)
- 非本番環境でのみ `db/clear` を実行

開発・テスト環境では従来どおり `confirmation_token`（backdoor トークンと同一）が必要。
