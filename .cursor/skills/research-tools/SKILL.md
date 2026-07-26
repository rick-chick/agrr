# Research Tools

研究用 GCS ホスティング（`/research/`）のデプロイと管理ツール。

## Scripts

- **sync-research-gcs.sh** — `public/research/` を GCS に同期し、sitemap を再生成して frontend バケットへアップロード
- **patch-research-vitepress-links.mjs** — VitePress `__VP_SITE_DATA__` の nav/sidebar リンクに `.html` を付与（リロード 404 回避）
- **inject-research-extensionless-redirect.mjs** — `404.html` に extensionless URL → `.html` リダイレクトを注入
- **inject-research-base-path-guard.mjs** — VitePress が落とす `/research` プレフィックスをクライアントで復元
- **inject-research-canonical.mjs** — 静的 HTML に `rel=canonical`（正規 URL `/research/...`）を冪等注入
- **serve-research-local.py** — ローカル静的サーバ（`/research_reports/*` エイリアス付き）
- **inject-research-google-analytics.rb** — 静的 HTML に Google Analytics を注入
- **inject-research-temperature-simulate-cta.mjs** — 温度要件レポートに公開プラン CTA を冪等注入（GDD CTA と同スタイル）

## Usage

プロジェクトルートから:

```bash
# 単体（既存の gcloud 認証のみ。GCP_SA_KEY 不要）
.cursor/skills/research-tools/scripts/sync-research-gcs.sh

# フロント production デプロイに同梱（既定で research も同期）
.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production
# research だけスキップする場合: SYNC_RESEARCH=0 gcp-frontend-deploy.sh deploy production
```

## Context

研究用の静的コンテンツを GCS + Cloud CDN でホスティング。デプロイ前に GA4 タグを動的に注入して、アクセス解析を有効化。

sitemap 生成は [deploy-frontend](../deploy-frontend/SKILL.md) の `generate-sitemap.mjs` を呼び出す。
