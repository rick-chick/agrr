# VitePress research rebuild checklist (external source repo)

AGRR hosts prebuilt research HTML under `public/research/`. VitePress source lives outside this repository.

## Goal

Fix extensionless internal nav links (`/research_reports/...` without `.html`) for static hosting, and keep EN locale paths consistent under `/research/en/`.

## Steps (source repository)

1. In `.vitepress/config.ts`:
   - Keep `base: '/research/'` for JA.
   - Build EN with `base: '/research/en/'` (all EN crop pages must use this base).
   - Set `cleanUrls: true` so build outputs `path/index.html` or consistent `.html` links.
2. **Exclude internal work markdown from the build** (do not copy into `research_reports/`):
   - `commands_template.md`, `README_commands.md`
   - `用語統一追加調査結果2.md`, `読みにくい・統一されていない箇所リスト.md`
   - `tomato/commands.md` (or any path outside `{crop}/{NN}_{category}/` report structure)
   - Move these to a non-published directory (e.g. `_internal/`) in the VitePress source repo.
3. **EN sidebar labels**: use English-only labels (e.g. `03 Pests & Diseases`, not `03 Pests 03 病害虫 Diseases`).
4. **cucumber `major_pests`**: create JA report at `research_reports/cucumber/03_pest_disease/major_pests.md`, then EN translation.
5. Rebuild and copy output into `agrr/public/research/`.
6. In agrr repo, run research sync prep (or full `sync-research-gcs.sh`) so post-build patches apply:
   - `patch-research-vitepress-links.mjs` (nav/sidebar `.html` suffixes)
   - `patch-research-vitepress-en-locale.mjs` (EN base `/research/en/` and English nav labels)
   - `patch-research-meta-descriptions.mjs` (per-page unique `meta description` from title + crop/category path)
   - `inject-research-hreflang.mjs`, `inject-research-noindex.mjs`, `inject-research-canonical.mjs`
7. Verify with LB rewrite `/research/*` → strip prefix to research bucket root.
8. Run `.cursor/skills/research-tools/scripts/sync-research-gcs.sh` from agrr repo.

Sitemap generation (`generate-sitemap-lib.mjs`) only indexes canonical crop report paths; non-conforming HTML is skipped even if present in `public/research/`.

## EN translation completion (agrr repo)

When EN Markdown is translated for a crop:

1. Copy rebuilt HTML into `public/research/en/`.
2. Run translation QA:

```bash
node scripts/verify-research-en-translation.mjs
```

3. Add the crop slug to `EN_TRANSLATED_CROPS` in [`scripts/research-en-translated-crops-lib.mjs`](../../scripts/research-en-translated-crops-lib.mjs).
4. Update tests in `scripts/research-en-translated-crops-lib.test.mjs` and run frontend tests via [test-common](../../.cursor/skills/test-common/SKILL.md).
5. Run `sync-research-gcs.sh` (or production frontend deploy) and `verify-seo-routing.sh`.

Translated crops are indexed (hreflang + sitemap). Untranslated EN crop reports receive `noindex` until added to the allowlist.

## Verification

```bash
node scripts/verify-research-en-translation.mjs
.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh
```

Extensionless research URLs should return 200 after rebuild (or remain 404 until then; sitemap lists `.html` URLs only).
