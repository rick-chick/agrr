import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  extractVpDocInnerHtml,
  replaceVpDocInnerHtml,
  splitJaEnVpDocPair,
} from './research-vp-doc-lib.mjs';

const VP_DOC_SHELL = (inner) =>
  `<main><div style="position:relative;" class="vp-doc has-sidebar"><div>${inner}</div></div></main>`;

const SAMPLE_INNER = '<h1>Potato GDD</h1><p>English content.</p>';

describe('extractVpDocInnerHtml', () => {
  it('extracts inner HTML from VitePress vp-doc block', () => {
    const html = VP_DOC_SHELL(SAMPLE_INNER);
    assert.equal(extractVpDocInnerHtml(html), SAMPLE_INNER);
  });

  it('returns null when vp-doc block is missing', () => {
    assert.equal(extractVpDocInnerHtml('<main><div class="vp-doc">no wrapper</div></main>'), null);
    assert.equal(extractVpDocInnerHtml('<html></html>'), null);
  });
});

describe('replaceVpDocInnerHtml', () => {
  it('replaces vp-doc inner content while preserving shell', () => {
    const html = VP_DOC_SHELL('<p>old</p>');
    const next = replaceVpDocInnerHtml(html, SAMPLE_INNER);
    assert.equal(extractVpDocInnerHtml(next), SAMPLE_INNER);
    assert.match(next, /class="vp-doc has-sidebar"/);
    assert.match(next, /<\/main>$/);
  });

  it('leaves HTML unchanged when vp-doc block is absent', () => {
    const html = '<html><body>unchanged</body></html>';
    assert.equal(replaceVpDocInnerHtml(html, SAMPLE_INNER), html);
  });
});

describe('splitJaEnVpDocPair', () => {
  it('returns JA inner HTML and EN shell when both pages have vp-doc', () => {
    const jaInner = '<h1>じゃがいも</h1>';
    const enInner = '<h1>Potato</h1>';
    const jaHtml = VP_DOC_SHELL(jaInner);
    const enHtml = VP_DOC_SHELL(enInner);

    const result = splitJaEnVpDocPair(jaHtml, enHtml);

    assert.equal(result.jaInner, jaInner);
    assert.equal(result.enShell, enHtml);
  });

  it('throws when JA or EN HTML lacks vp-doc block', () => {
    const valid = VP_DOC_SHELL(SAMPLE_INNER);
    const invalid = '<main></main>';

    assert.throws(
      () => splitJaEnVpDocPair(invalid, valid),
      /vp-doc block not found/
    );
    assert.throws(
      () => splitJaEnVpDocPair(valid, invalid),
      /vp-doc block not found/
    );
  });
});
