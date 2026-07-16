import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';
import {
  RESEARCH_CROPS,
  buildTemperatureCtaHtml,
  verifyAllTemperatureRequirementCtas
} from './verify-research-temperature-cta-lib.mjs';

const RESEARCH_DIR = join(process.cwd(), 'public', 'research');

describe('buildTemperatureCtaHtml', () => {
  it('builds JA tomato CTA aligned with GDD style', () => {
    const html = buildTemperatureCtaHtml('ja', 'tomato');
    assert.match(html, /agrr-gdd-simulate-cta/);
    assert.match(html, /このレポートの温度要件を/);
    assert.match(html, /https:\/\/agrr\.net\/public-plans\/new/);
    assert.match(html, /トマトの栽培計画をシミュレート →/);
  });

  it('builds EN tomato CTA aligned with GDD style', () => {
    const html = buildTemperatureCtaHtml('en', 'tomato');
    assert.match(html, /Try it in your region/);
    assert.match(html, /these temperature requirements apply/);
    assert.match(html, /Simulate Tomato cultivation →/);
  });

  it('covers all research crops in both locales', () => {
    for (const crop of RESEARCH_CROPS) {
      assert.doesNotThrow(() => buildTemperatureCtaHtml('ja', crop));
      assert.doesNotThrow(() => buildTemperatureCtaHtml('en', crop));
    }
  });
});

describe('temperature requirements pages', () => {
  it('include public-plan CTA on all 15 crops x JA/EN pages and JA JS bundles', () => {
    const failures = verifyAllTemperatureRequirementCtas(RESEARCH_DIR);
    assert.deepEqual(
      failures,
      [],
      failures.map((f) => `${f.path}: ${f.errors.join(', ')}`).join('\n')
    );
  });
});
