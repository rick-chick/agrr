import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  CAPTURE_LOCALES,
  agentPngFilename,
  documentHtmlLang,
  navigatorLanguageTag,
  pngBasename,
  railsLocaleCookieValue,
} from './capture-locales.mjs';

test('CAPTURE_LOCALES lists ja, en, and in for agent PNG matrix', () => {
  assert.deepEqual(CAPTURE_LOCALES, ['ja', 'en', 'in']);
});

test('pngBasename maps route patterns to stable filenames', () => {
  assert.equal(pngBasename(''), 'home');
  assert.equal(pngBasename('**'), 'not-found');
  assert.equal(pngBasename('plans/:id/work'), 'plans_id_work');
  assert.equal(pngBasename('farms/:id/edit'), 'farms_id_edit');
});

test('agentPngFilename appends locale suffix used by verify-capture-complete', () => {
  assert.equal(agentPngFilename('farms', 'ja'), 'farms.ja.png');
  assert.equal(agentPngFilename('plans/:id/work', 'en'), 'plans_id_work.en.png');
  assert.equal(agentPngFilename('entry-schedule', 'in'), 'entry-schedule.in.png');
});

test('documentHtmlLang maps in to hi (applyAppLang parity)', () => {
  assert.equal(documentHtmlLang('ja'), 'ja');
  assert.equal(documentHtmlLang('en'), 'en');
  assert.equal(documentHtmlLang('in'), 'hi');
});

test('navigatorLanguageTag matches browser locale tags used in installCaptureLocale', () => {
  assert.equal(navigatorLanguageTag('ja'), 'ja-JP');
  assert.equal(navigatorLanguageTag('en'), 'en-US');
  assert.equal(navigatorLanguageTag('in'), 'hi-IN');
});

test('railsLocaleCookieValue maps en to us for Rails cookie', () => {
  assert.equal(railsLocaleCookieValue('ja'), 'ja');
  assert.equal(railsLocaleCookieValue('en'), 'us');
  assert.equal(railsLocaleCookieValue('in'), 'in');
});
