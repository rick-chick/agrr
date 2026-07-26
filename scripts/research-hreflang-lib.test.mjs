import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  alternateLocaleRelativePath,
  buildResearchHreflangSnippet,
  researchRelativePathToUrlPath,
  resolveResearchHreflangUrls,
} from './research-hreflang-lib.mjs';

describe('researchRelativePathToUrlPath', () => {
  it('maps locale index pages', () => {
    assert.equal(researchRelativePathToUrlPath('index.html'), '/research/');
    assert.equal(researchRelativePathToUrlPath('en/index.html'), '/research/en/');
  });

  it('maps JA and EN crop report pages', () => {
    assert.equal(
      researchRelativePathToUrlPath(
        'research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      '/research/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
    );
    assert.equal(
      researchRelativePathToUrlPath(
        'en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
      ),
      '/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html'
    );
  });
});

describe('alternateLocaleRelativePath', () => {
  it('pairs JA and EN index pages', () => {
    assert.equal(alternateLocaleRelativePath('index.html'), 'en/index.html');
    assert.equal(alternateLocaleRelativePath('en/index.html'), 'index.html');
  });

  it('pairs JA and EN crop report pages', () => {
    const ja = 'research_reports/tomato/01_environmental_requirements/gdd_requirements.html';
    const en = 'en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html';
    assert.equal(alternateLocaleRelativePath(ja), en);
    assert.equal(alternateLocaleRelativePath(en), ja);
  });

  it('returns null for non-paired pages', () => {
    assert.equal(alternateLocaleRelativePath('404.html'), null);
  });
});

describe('buildResearchHreflangSnippet', () => {
  it('emits canonical and bidirectional hreflang including x-default', () => {
    const snippet = buildResearchHreflangSnippet({
      canonicalUrl: 'https://agrr.net/research/',
      jaUrl: 'https://agrr.net/research/',
      enUrl: 'https://agrr.net/research/en/',
    });

    assert.match(snippet, /<link rel="canonical" href="https:\/\/agrr\.net\/research\/">/);
    assert.match(snippet, /<link rel="alternate" hreflang="ja" href="https:\/\/agrr\.net\/research\/">/);
    assert.match(
      snippet,
      /<link rel="alternate" hreflang="en" href="https:\/\/agrr\.net\/research\/en\/">/
    );
    assert.match(
      snippet,
      /<link rel="alternate" hreflang="x-default" href="https:\/\/agrr\.net\/research\/">/
    );
  });

  it('uses EN URL as canonical on EN pages', () => {
    const snippet = buildResearchHreflangSnippet({
      canonicalUrl: 'https://agrr.net/research/en/',
      jaUrl: 'https://agrr.net/research/',
      enUrl: 'https://agrr.net/research/en/',
    });

    assert.match(snippet, /<link rel="canonical" href="https:\/\/agrr\.net\/research\/en\/">/);
  });
});

describe('resolveResearchHreflangUrls', () => {
  it('resolves paired JA page URLs', () => {
    const result = resolveResearchHreflangUrls({
      relativePath: 'research_reports/tomato/01_environmental_requirements/gdd_requirements.html',
      alternateExists: true,
      baseUrl: 'https://agrr.net',
    });

    assert.deepEqual(result, {
      locale: 'ja',
      canonicalUrl:
        'https://agrr.net/research/research_reports/tomato/01_environmental_requirements/gdd_requirements.html',
      jaUrl:
        'https://agrr.net/research/research_reports/tomato/01_environmental_requirements/gdd_requirements.html',
      enUrl:
        'https://agrr.net/research/en/research_reports/tomato/01_environmental_requirements/gdd_requirements.html',
    });
  });

  it('returns null when alternate locale file is missing', () => {
    const result = resolveResearchHreflangUrls({
      relativePath: 'research_reports/tomato/01_environmental_requirements/gdd_requirements.html',
      alternateExists: false,
      baseUrl: 'https://agrr.net',
    });

    assert.equal(result, null);
  });
});
