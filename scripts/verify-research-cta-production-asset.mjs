/**
 * Post-deploy check: production research CTA navigation bypass.
 * Primary: inline capture script in no-cache HTML (works even when immutable JS is stale).
 * Secondary: external JS should not contain pre-#484 attachPublicPlanNavigation.
 */
import {
  verifyResearchCtaAsset,
  verifyResearchCtaScriptInContent
} from './research-simulate-cta-lib.mjs';

const PRODUCTION_HTML_URL =
  'https://agrr.net/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html';
const PRODUCTION_CTA_URL = 'https://agrr.net/research/assets/agrr-gdd-simulate-cta.js';

const noCache = { headers: { 'Cache-Control': 'no-cache' } };

const [htmlResponse, jsResponse] = await Promise.all([
  fetch(PRODUCTION_HTML_URL, noCache),
  fetch(PRODUCTION_CTA_URL, noCache)
]);

if (!htmlResponse.ok) {
  console.error(
    `[verify-research-cta-production] HTTP ${htmlResponse.status} for ${PRODUCTION_HTML_URL}`
  );
  process.exit(1);
}

if (!jsResponse.ok) {
  console.error(
    `[verify-research-cta-production] HTTP ${jsResponse.status} for ${PRODUCTION_CTA_URL}`
  );
  process.exit(1);
}

const html = await htmlResponse.text();
const js = await jsResponse.text();
const errors = [
  ...verifyResearchCtaScriptInContent(html),
  ...verifyResearchCtaAsset(js)
];

if (errors.length > 0) {
  console.error('[verify-research-cta-production] production check failed:');
  for (const error of errors) {
    console.error(`  - ${error}`);
  }
  console.error(
    '\nRun .cursor/skills/research-tools/scripts/sync-research-gcs.sh',
    'or .cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production',
    '(uses existing gcloud auth; GCP_SA_KEY not required).'
  );
  process.exit(1);
}

console.log('[verify-research-cta-production] OK — production HTML/JS include CTA navigation bypass');
