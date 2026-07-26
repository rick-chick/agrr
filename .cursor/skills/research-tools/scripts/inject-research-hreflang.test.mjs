import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildResearchHreflangSnippet,
  injectResearchHreflangIntoHtml,
  resolveResearchHreflangUrls,
} from '../../../../scripts/research-hreflang-lib.mjs';

const SAMPLE_HTML = `<!DOCTYPE html>
<html>
  <head>
    <title>Sample</title>
  </head>
  <body></body>
</html>`;

describe('inject-research-hreflang', () => {
  it('injects canonical and hreflang into HTML head', () => {
    const resolved = resolveResearchHreflangUrls({
      relativePath: 'index.html',
      alternateExists: true,
      baseUrl: 'https://agrr.net',
    });
    assert.ok(resolved);

    const snippet = buildResearchHreflangSnippet(resolved);
    const html = injectResearchHreflangIntoHtml(SAMPLE_HTML, snippet);

    assert.match(html, /rel="canonical" href="https:\/\/agrr\.net\/research\/"/);
    assert.match(html, /hreflang="ja"/);
    assert.match(html, /hreflang="en"/);
    assert.match(html, /hreflang="x-default"/);
  });

  it('replaces existing hreflang markers idempotently', () => {
    const resolved = resolveResearchHreflangUrls({
      relativePath: 'en/index.html',
      alternateExists: true,
      baseUrl: 'https://agrr.net',
    });
    assert.ok(resolved);

    const snippet = buildResearchHreflangSnippet(resolved);
    const first = injectResearchHreflangIntoHtml(SAMPLE_HTML, snippet);
    const second = injectResearchHreflangIntoHtml(first, snippet);

    assert.equal(first, second);
    assert.match(second, /rel="canonical" href="https:\/\/agrr\.net\/research\/en\/"/);
  });
});
