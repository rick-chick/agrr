# VitePress research rebuild checklist (external source repo)

AGRR hosts prebuilt research HTML under `public/research/`. VitePress source lives outside this repository.

## Goal

Fix extensionless internal nav links (`/research_reports/...` without `.html`) for static hosting.

## Steps (source repository)

1. In `.vitepress/config.ts`:
   - Keep `base: '/research/'` (EN: `base: '/research/en/'`).
   - Set `cleanUrls: true` so build outputs `path/index.html` or consistent `.html` links.
2. Rebuild and copy output into `agrr/public/research/`.
3. Verify with LB rewrite `/research/*` → strip prefix to research bucket root.
4. Run `.cursor/skills/research-tools/scripts/sync-research-gcs.sh` from agrr repo.

## Verification

```bash
.cursor/skills/deploy-frontend/scripts/verify-seo-routing.sh
```

Extensionless research URLs should return 200 after rebuild (or remain 404 until then; sitemap lists `.html` URLs only).
