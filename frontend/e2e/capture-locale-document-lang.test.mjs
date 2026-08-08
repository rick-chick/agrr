import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { expectedCaptureDocumentLang } from './capture-locales.mjs';

describe('expectedCaptureDocumentLang', () => {
  it('forces en on /en mirror route regardless of capture locale', () => {
    assert.equal(expectedCaptureDocumentLang('en', 'ja'), 'en');
    assert.equal(expectedCaptureDocumentLang('en', 'en'), 'en');
    assert.equal(expectedCaptureDocumentLang('en', 'in'), 'en');
  });

  it('maps in capture locale to hi on normal routes', () => {
    assert.equal(expectedCaptureDocumentLang('home', 'in'), 'hi');
    assert.equal(expectedCaptureDocumentLang('crops', 'ja'), 'ja');
  });
});
