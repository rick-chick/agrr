import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { documentHtmlLang, ogLocaleForAppLang } from './document-html-lang.mjs';

describe('document-html-lang.mjs', () => {
  it('maps in app locale to hi HTML lang and hi_IN og locale', () => {
    assert.equal(documentHtmlLang('in'), 'hi');
    assert.equal(ogLocaleForAppLang('in'), 'hi_IN');
  });

  it('keeps ja and en unchanged for HTML lang', () => {
    assert.equal(documentHtmlLang('ja'), 'ja');
    assert.equal(documentHtmlLang('en'), 'en');
    assert.equal(ogLocaleForAppLang('ja'), 'ja_JP');
    assert.equal(ogLocaleForAppLang('en'), 'en_US');
  });
});
