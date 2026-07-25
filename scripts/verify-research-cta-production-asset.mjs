/**
 * Post-deploy check: production research CTA JS must include the #484 navigation fix.
 * Fails when agrr-research-backend still serves the pre-fix asset with
 * attachPublicPlanNavigation (bubble-phase) and without target="_blank".
 */
const PRODUCTION_CTA_URL = 'https://agrr.net/research/assets/agrr-gdd-simulate-cta.js';

const response = await fetch(PRODUCTION_CTA_URL, {
  headers: { 'Cache-Control': 'no-cache' }
});

if (!response.ok) {
  console.error(`[verify-research-cta-production] HTTP ${response.status} for ${PRODUCTION_CTA_URL}`);
  process.exit(1);
}

const content = await response.text();
const errors = [];

if (content.includes('attachPublicPlanNavigation')) {
  errors.push('still contains attachPublicPlanNavigation (stale pre-#484 asset)');
}

if (!content.includes('target="_blank"')) {
  errors.push('missing target="_blank" on sidebar/mobile CTA links');
}

if (!content.includes('agrr-research-sidebar-cta')) {
  errors.push('missing agrr-research-sidebar-cta class');
}

if (errors.length > 0) {
  console.error('[verify-research-cta-production] production asset check failed:');
  for (const error of errors) {
    console.error(`  - ${error}`);
  }
  console.error(
    '\nRun .cursor/skills/research-tools/scripts/sync-research-gcs.sh or the Research deploy workflow.'
  );
  process.exit(1);
}

console.log('[verify-research-cta-production] OK — production CTA asset includes navigation bypass fix');
