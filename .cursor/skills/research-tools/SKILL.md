# Research Tools

研究用 GCS ホスティング（`/research/`）のデプロイと管理ツール。

## Scripts

- **sync-research-gcs.sh** — `public/research/` を GCS に同期し、sitemap を再生成して frontend バケットへアップロード
- **inject-research-google-analytics.rb** — 静的 HTML に Google Analytics を注入

## Usage

プロジェクトルートから:

```bash
.cursor/skills/research-tools/scripts/sync-research-gcs.sh
```

## Context

研究用の静的コンテンツを GCS + Cloud CDN でホスティング。デプロイ前に GA4 タグを動的に注入して、アクセス解析を有効化。

sitemap 生成は [deploy-frontend](../deploy-frontend/SKILL.md) の `generate-sitemap.mjs` を呼び出す。
