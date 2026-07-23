import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { join } from 'node:path';

import {
  RESEARCH_CROPS,
  buildMobileCtaCopy,
  buildPublicPlanHref,
  buildSidebarCtaCopy,
  cropSlugFromResearchPath,
  isEnglishResearchPath,
  isResearchRequirementsPage,
  pageTypeFromResearchPath,
  verifyAllResearchRequirementsCtaScripts
} from './research-simulate-cta-lib.mjs';

const RESEARCH_DIR = join(process.cwd(), 'public', 'research');

describe('isResearchRequirementsPage', () => {
  it('matches temperature and gdd requirement paths', () => {
    assert.equal(
      isResearchRequirementsPage(
        '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
      ),
      true
    );
    assert.equal(
      isResearchRequirementsPage(
        '/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      true
    );
    assert.equal(isResearchRequirementsPage('/research/'), false);
  });
});

describe('cropSlugFromResearchPath', () => {
  it('extracts crop slug from JA and EN paths', () => {
    assert.equal(
      cropSlugFromResearchPath(
        '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
      ),
      'tomato'
    );
    assert.equal(
      cropSlugFromResearchPath(
        '/research/en/research_reports/bell_pepper/01_environmental_requirements/gdd_requirements.html'
      ),
      'bell_pepper'
    );
  });
});

describe('buildPublicPlanHref', () => {
  it('includes crop query param for primary CTA links', () => {
    const href = buildPublicPlanHref('tomato', { utmMedium: 'temp_sidebar' });
    assert.match(href, /^\/public-plans\/new\?/);
    assert.match(href, /crop=tomato/);
    assert.match(href, /utm_medium=temp_sidebar/);
  });
});

describe('buildSidebarCtaCopy', () => {
  it('builds JA temperature copy with regional title', () => {
    const copy = buildSidebarCtaCopy('ja', 'tomato', 'temperature');
    assert.equal(copy.title, 'あなたの地域で試す');
    assert.match(copy.body, /トマト/);
    assert.equal(copy.button, 'シミュレート →');
  });

  it('builds EN gdd copy', () => {
    const copy = buildSidebarCtaCopy('en', 'tomato', 'gdd');
    assert.equal(copy.title, 'Try it in your region');
    assert.match(copy.body, /Simulate Tomato GDD/);
    assert.equal(copy.button, 'Simulate →');
  });

  it('covers all research crops in both locales and page types', () => {
    for (const crop of RESEARCH_CROPS) {
      assert.doesNotThrow(() => buildSidebarCtaCopy('ja', crop, 'temperature'));
      assert.doesNotThrow(() => buildSidebarCtaCopy('en', crop, 'gdd'));
      assert.doesNotThrow(() => buildMobileCtaCopy('ja', crop));
      assert.doesNotThrow(() => buildMobileCtaCopy('en', crop));
    }
  });
});

describe('pageTypeFromResearchPath', () => {
  it('detects temperature vs gdd pages', () => {
    assert.equal(
      pageTypeFromResearchPath(
        '/research/research_reports/tomato/01_environmental_requirements/temperature_requirements.html'
      ),
      'temperature'
    );
    assert.equal(
      pageTypeFromResearchPath(
        '/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      'gdd'
    );
  });
});

describe('isEnglishResearchPath', () => {
  it('detects EN locale prefix', () => {
    assert.equal(
      isEnglishResearchPath(
        '/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      true
    );
    assert.equal(
      isEnglishResearchPath(
        '/research/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      false
    );
  });
});

describe('research requirements pages', () => {
  it('inject script and runtime asset include sticky/mobile CTA classes and crop param', () => {
    const failures = verifyAllResearchRequirementsCtaScripts(RESEARCH_DIR);
    assert.deepEqual(
      failures,
      [],
      failures.map((f) => `${f.path}: ${f.errors.join(', ')}`).join('\n')
    );
  });
});
