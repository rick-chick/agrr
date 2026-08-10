import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildResearchNoindexSnippet,
  hasResearchNoindex,
  injectResearchNoindexIntoHtml,
  removeResearchNoindexFromHtml,
} from './inject-research-noindex-lib.mjs';

const SAMPLE_HTML = `<!DOCTYPE html>
<html>
  <head>
    <title>Sample</title>
  </head>
  <body></body>
</html>`;

describe('injectResearchNoindexIntoHtml', () => {
  it('injects robots noindex before </head>', () => {
    const out = injectResearchNoindexIntoHtml(SAMPLE_HTML);
    assert.match(out, /<meta name="robots" content="noindex">/);
    assert.match(out, /<!-- agrr-research-noindex:start -->/);
    assert.equal(hasResearchNoindex(out), true);
  });

  it('replaces existing noindex marker block idempotently', () => {
    const first = injectResearchNoindexIntoHtml(SAMPLE_HTML);
    const second = injectResearchNoindexIntoHtml(first);
    assert.equal(first, second);
    assert.equal((second.match(/<!-- agrr-research-noindex:start -->/g) || []).length, 1);
  });
});

describe('removeResearchNoindexFromHtml', () => {
  it('removes noindex marker block', () => {
    const withNoindex = injectResearchNoindexIntoHtml(SAMPLE_HTML);
    const out = removeResearchNoindexFromHtml(withNoindex);
    assert.equal(hasResearchNoindex(out), false);
    assert.doesNotMatch(out, /agrr-research-noindex/);
  });
});

describe('buildResearchNoindexSnippet', () => {
  it('wraps noindex meta with markers', () => {
    assert.match(buildResearchNoindexSnippet(), /content="noindex"/);
  });
});
