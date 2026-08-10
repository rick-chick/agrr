# Research Tools

研究用 GCS ホスティング（`/research/`）のデプロイと管理ツール。

## Scripts

- **sync-research-gcs.sh** — `public/research/` を GCS に同期し、sitemap を再生成して frontend バケットへアップロード
- **patch-research-vitepress-links.mjs** — VitePress `__VP_SITE_DATA__` の nav/sidebar リンクに `.html` を付与（リロード 404 回避）
- **patch-research-vitepress-en-locale.mjs** — EN 作物レポートの VitePress `base` を `/research/en/` に統一し、混在 sidebar ラベルを英語化
- **inject-research-noindex.mjs** — 未翻訳 EN 作物レポートに `noindex` を注入（`EN_TRANSLATED_CROPS` 以外）
- **inject-research-hreflang.mjs** — 対応 JA/EN ページに canonical + hreflang（ja/en/x-default）を注入
- **inject-research-canonical.mjs** — 静的 HTML に `/research/` 正規 URL 向け `rel=canonical` を注入
- **patch-research-meta-descriptions.mjs** — レポート HTML の `meta description` をページタイトルとパス（作物・カテゴリ）から一意化
- **inject-research-extensionless-redirect.mjs** — `404.html` に extensionless URL → `.html` リダイレクトを注入
- **inject-research-base-path-guard.mjs** — VitePress が落とす `/research` プレフィックスをクライアントで復元
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

EN 翻訳完了後は [`scripts/research-en-translated-crops-lib.mjs`](../../scripts/research-en-translated-crops-lib.mjs) の allowlist を更新し、`node scripts/verify-research-en-translation.mjs` で QA する。手順は [vitepress-rebuild-checklist](../../docs/seo/vitepress-rebuild-checklist.md) の「EN translation completion」を参照。
