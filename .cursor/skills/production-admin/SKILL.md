# Production Admin Tools

管理者が本番環境で実行するスクリプトを集約。ユーザー管理、スキーマ確認、バックドア状態確認など。

## Scripts

- **set_user_admin.sh** — ユーザーを管理者に昇格
- **get_production_schemas.sh** — 本番 SQLite スキーマを取得
- **check_production_users.sh** — 本番環境のユーザーリストを表示
- **check_production_backdoor.sh** — バックドア API の稼働状態確認
- **show_backdoor_token.rb** — バックドア認証トークンを表示

## Usage

リポジトリルートの `.env.gcp`（`env.gcp.example` から作成）が必要。API 呼び出しは **ロードバランサ経由の公開 URL**（`ALLOWED_HOSTS` の先頭ホスト、または `PRODUCTION_PUBLIC_URL`）を使う。Cloud Run の `*.run.app` は ingress が LB 限定のとき **404** になる。

```bash
.cursor/skills/production-admin/scripts/set_user_admin.sh <user_id>
.cursor/skills/production-admin/scripts/get_production_schemas.sh
.cursor/skills/production-admin/scripts/check_production_users.sh
.cursor/skills/production-admin/scripts/check_production_backdoor.sh
.cursor/skills/production-admin/scripts/show_backdoor_token.rb
```

⚠️ これらは本番環境に直接影響を与えるため、実行時は注意が必要。
