---
name: deploy-frontend
description: Deploy the Angular frontend to GCP Cloud Storage (production). Use when the user asks to deploy frontend, Angular, production frontend, SEO sitemap, robots.txt, or verify SEO routing. Runs gcp-frontend-deploy.sh to build, sync to GCS, and invalidate CDN cache.
---

# フロントエンドデプロイ (Production)

Angular フロントエンドを GCS バケット + Cloud CDN にデプロイするスキル。

## 前提条件

- `gcloud` / `gsutil` CLI がインストール・認証済み
- Node.js / npm がインストール済み
- `.env.gcp.frontend` がプロジェクトルートに存在

`.env.gcp.frontend` の必須項目:

```
PROJECT_ID=agrr-475323
BUCKET_NAME=agrr-frontend-prod
API_BASE_URL=https://agrr.net
URL_MAP_NAME=agrr-frontend-url-map-simple
```

## デプロイ手順

### 1. 事前確認

```
Task Progress:
- [ ] masterブランチにいるか
- [ ] 未コミットの変更がないか
- [ ] テストが通っているか
- [ ] .env.gcp.frontend が存在するか
```

確認コマンド:

```bash
git branch --show-current
git status --short
```

### 2. デプロイ実行

プロジェクトルートで以下を実行:

```bash
.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production
```

スクリプトの処理内容:
1. `.env.gcp.frontend` から環境変数を読み込み
2. `scripts/generate-sitemap.mjs`（同スキル内）で `frontend/public/sitemap.xml` を生成
3. `frontend/` で `npm ci` + `ng build --configuration=production`
4. ビルド成果物を `static/` プレフィックス配下に再配置
5. `index.html` に `window.API_BASE_URL` を注入
6. 公開 SPA ルート用に `index.html` ミラー（`about` 等）を配置
7. GCS バケット (`agrr-frontend-prod`) に `gsutil rsync` で同期（`robots.txt` / `sitemap.xml` / `404.html` はバケット root）
8. Cache-Control ヘッダーを設定
9. Cloud CDN キャッシュ無効化 (`URL_MAP_NAME` 指定時)

**注意**: `gsutil web set -e index.html` は実行しない（SPA が HTTP 404 になる）。

### 3. ドライラン (任意)

実際にデプロイせずコマンドを確認:

```bash
DRY_RUN=1 .cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production
```

### 4. デプロイ後の確認

```bash
# バケット内容確認
gsutil ls gs://agrr-frontend-prod/

# index.html にAPI_BASE_URLが注入されているか
gsutil cat gs://agrr-frontend-prod/index.html | head -20

# SEO ルーティング検証（本番 curl）
.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh

# Search Console へ sitemap 再送信（ADC + webmasters スコープ要）
.cursor/skills/deploy-frontend/scripts/submit-sitemap-gsc.sh
```

## SEO スクリプト（同スキル `scripts/`）

| スクリプト | 用途 |
|-----------|------|
| `generate-sitemap.mjs` | SPA 公開ルート + index 対象の research HTML から sitemap 生成（フィルタ: `generate-sitemap-lib.mjs`） |
| `generate-sitemap.test.mjs` | `node --test generate-sitemap.test.mjs` — 正規レポート構造の allowlist 検証 |
| `verify-seo-routing.sh` | 本番 HTTP ステータス・リダイレクト・sitemap 件数の検証 |
| `submit-sitemap-gsc.sh` | GSC API で `https://agrr.net/sitemap.xml` を再送信（プロパティ `sc-domain:agrr.net`） |

GSC 初回認証:

```bash
gcloud auth application-default login \
  --scopes="openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/webmasters"
gcloud auth application-default set-quota-project agrr-475323
```

## テスト環境へのデプロイ

**ローカル UI + GCP `agrr-test` API** は [gcp-test-local](../gcp-test-local/SKILL.md)（新規スクリプトを増やさない）。

GCS 静的のみ（`agrr-test.net` + LB がある場合）: `.env.gcp.frontend.test` + `deploy test`。

## CI/CD (GitHub Actions)

`main` ブランチへの push/PR で自動デプロイ (`.github/workflows/frontend-deploy.yml`):
- PR → テスト環境
- push (マージ) → プロダクション環境

## トラブルシューティング

**ビルド失敗**: `cd frontend && npm ci && npm run build` を手動実行してエラーを確認。

**gsutil 権限エラー**: `gcloud auth login` を実行。サービスアカウントの権限 (`storage.objectAdmin`) を確認。

**CDN キャッシュが残る**: `gcloud compute url-maps invalidate-cdn-cache agrr-frontend-prod --path "/*" --project agrr-475323` を手動実行。

**API_BASE_URL が反映されない**: `index.html` を確認し、`<script>window.API_BASE_URL = ...` が `<head>` 内に注入されているか確認。
