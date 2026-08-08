import assert from 'node:assert/strict';
import { test } from 'node:test';

import { expectedDocumentHtmlLangForCapture } from './capture-locales.mjs';

test('expectedDocumentHtmlLangForCapture uses app locale except /en mirror', () => {
  assert.equal(expectedDocumentHtmlLangForCapture('about', 'ja'), 'ja');
  assert.equal(expectedDocumentHtmlLangForCapture('about', 'en'), 'en');
  assert.equal(expectedDocumentHtmlLangForCapture('about', 'in'), 'hi');
  assert.equal(expectedDocumentHtmlLangForCapture('en', 'ja'), 'en');
  assert.equal(expectedDocumentHtmlLangForCapture('en', 'en'), 'en');
  assert.equal(expectedDocumentHtmlLangForCapture('en', 'in'), 'en');
});
