import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const LOCAL_ASSET = join(process.cwd(), 'public', 'research', 'assets', 'agrr-gdd-simulate-cta.js');
const LOCAL_HTML = join(
  process.cwd(),
  'public',
  'research',
  'research_reports',
  'tomato',
  '01_environmental_requirements',
  'temperature_requirements.html'
);

function verifyCtaAssetContent(content) {
  const errors = [];
  if (content.includes('attachPublicPlanNavigation')) {
    errors.push('still contains attachPublicPlanNavigation');
  }
  if (!content.includes('target="_blank"')) {
    errors.push('missing target="_blank"');
  }
  if (!content.includes('agrr-research-sidebar-cta')) {
    errors.push('missing agrr-research-sidebar-cta');
  }
  return errors;
}

function verifyCtaHtmlContent(content) {
  const errors = [];
  if (!content.includes('stopImmediatePropagation')) {
    errors.push('missing inline CTA navigation bypass');
  }
  if (!content.includes('agrr-research-cta:start')) {
    errors.push('missing research CTA script marker');
  }
  return errors;
}

describe('verifyResearchCtaProductionAsset', () => {
  it('local research CTA asset satisfies production checks', () => {
    const content = readFileSync(LOCAL_ASSET, 'utf8');
    const errors = verifyCtaAssetContent(content);
    assert.deepEqual(errors, []);
  });

  it('local research HTML includes inline CTA navigation bypass', () => {
    const content = readFileSync(LOCAL_HTML, 'utf8');
    const errors = verifyCtaHtmlContent(content);
    assert.deepEqual(errors, []);
  });
});
