import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildCanonicalSnippet,
  canonicalUrlForResearchFile,
  hasResearchHreflangMarkers,
  injectCanonicalIntoHtml,
  removeCanonicalMarkerFromHtml,
} from './inject-research-canonical-lib.mjs';

describe('canonicalUrlForResearchFile', () => {
  it('returns canonical URL for crop report HTML', () => {
    assert.equal(
      canonicalUrlForResearchFile(
        'research_reports/radish/03_pest_disease/major_pests.html'
      ),
      'https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html'
    );
  });
});

describe('injectCanonicalIntoHtml', () => {
  it('injects link rel=canonical before </head>', () => {
    const html = '<html><head><title>x</title></head><body></body></html>';
    const out = injectCanonicalIntoHtml(
      html,
      'https://agrr.net/research/research_reports/radish/03_pest_disease/major_pests.html'
    );
    assert.match(out, /<link rel="canonical" href="https:\/\/agrr\.net\/research\/research_reports\/radish\/03_pest_disease\/major_pests\.html">/);
    assert.match(out, /<!-- agrr-research-canonical:start -->/);
  });

  it('replaces existing canonical marker block idempotently', () => {
    const first = injectCanonicalIntoHtml(
      '<html><head></head></html>',
      'https://agrr.net/research/'
    );
    const second = injectCanonicalIntoHtml(
      first,
      'https://agrr.net/research/'
    );
    assert.equal(
      (second.match(/<!-- agrr-research-canonical:start -->/g) || []).length,
      1
    );
    assert.equal(second, first);
  });

  it('skips injection when hreflang markers already provide canonical', () => {
    const html = `<html><head>
<!-- agrr-research-canonical:start -->
<link rel="canonical" href="https://agrr.net/research/legacy">
<!-- agrr-research-canonical:end -->
<!-- agrr-research-hreflang:start -->
<link rel="canonical" href="https://agrr.net/research/en/">
<!-- agrr-research-hreflang:end -->
</head></html>`;
    const out = injectCanonicalIntoHtml(html, 'https://agrr.net/research/');
    assert.doesNotMatch(out, /agrr-research-canonical/);
    assert.match(out, /hreflang/);
    assert.equal(hasResearchHreflangMarkers(html), true);
  });

  it('removeCanonicalMarkerFromHtml strips standalone canonical block', () => {
    const html = `<html><head>${buildCanonicalSnippet('https://agrr.net/research/')}</head></html>`;
    const out = removeCanonicalMarkerFromHtml(html);
    assert.doesNotMatch(out, /agrr-research-canonical/);
  });
});

describe('buildCanonicalSnippet', () => {
  it('wraps canonical link with markers', () => {
    assert.match(
      buildCanonicalSnippet('https://agrr.net/research/'),
      /rel="canonical"/
    );
  });
});
