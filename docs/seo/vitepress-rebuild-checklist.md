# VitePress research rebuild checklist (external source repo)

AGRR hosts prebuilt research HTML under `public/research/`. VitePress source lives outside this repository.

## Goal

Fix extensionless internal nav links (`/research_reports/...` without `.html`) for static hosting.

## Steps (source repository)

1. In `.vitepress/config.ts`:
   - Keep `base: '/research/'` (EN: `base: '/research/en/'`).
   - Set `cleanUrls: true` so build outputs `path/index.html` or consistent `.html` links.
2. **Exclude internal work markdown from the build** (do not copy into `research_reports/`):
   - `commands_template.md`, `README_commands.md`
   - `用語統一追加調査結果2.md`, `読みにくい・統一されていない箇所リスト.md`
   - `tomato/commands.md` (or any path outside `{crop}/{NN}_{category}/` report structure)
   - Move these to a non-published directory (e.g. `_internal/`) in the VitePress source repo.
3. Rebuild and copy output into `agrr/public/research/`.
4. Verify with LB rewrite `/research/*` → strip prefix to research bucket root.
5. Run `.cursor/skills/research-tools/scripts/sync-research-gcs.sh` from agrr repo.

Sitemap generation (`generate-sitemap-lib.mjs`) only indexes canonical crop report paths; non-conforming HTML is skipped even if present in `public/research/`.

## Verification

```bash
.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh
```

Extensionless research URLs should return 200 after rebuild (or remain 404 until then; sitemap lists `.html` URLs only).
