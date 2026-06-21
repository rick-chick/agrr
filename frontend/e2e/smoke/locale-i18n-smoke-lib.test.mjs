import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  containsDevanagariScript,
  containsJapaneseScript,
  findLocaleI18nViolations,
  findRawTranslationKeys,
  findUninterpolatedPlaceholders,
} from './locale-i18n-smoke-lib.mjs';

test('findRawTranslationKeys detects dotted ngx-translate keys', () => {
  const text = 'Settings\nplans.task_schedules.title\nSave';
  assert.deepEqual(findRawTranslationKeys(text), ['plans.task_schedules.title']);
});

test('findRawTranslationKeys ignores semver-like numeric segments', () => {
  const text = 'Version 1.2.3 is current';
  assert.deepEqual(findRawTranslationKeys(text), []);
});

test('findUninterpolatedPlaceholders detects %{count} remnants', () => {
  const text = 'Showing %{count} items';
  assert.deepEqual(findUninterpolatedPlaceholders(text), ['%{count}']);
});

test('containsJapaneseScript detects hiragana and kanji', () => {
  assert.equal(containsJapaneseScript('農場一覧'), true);
  assert.equal(containsJapaneseScript('Farm list'), false);
});

test('containsDevanagariScript detects Hindi UI text', () => {
  assert.equal(containsDevanagariScript('खेत सूची'), true);
  assert.equal(containsDevanagariScript('Farm list'), false);
});

test('findLocaleI18nViolations flags known leak patterns (RED→GREEN fixture)', () => {
  const leaked = 'plans.entry_schedule.retry\n%{name} was deleted.\n農場';
  const enViolations = findLocaleI18nViolations(leaked, 'en');
  assert.ok(enViolations.some((v) => v.startsWith('raw i18n key:')));
  assert.ok(enViolations.some((v) => v.startsWith('uninterpolated placeholder:')));
  assert.ok(enViolations.some((v) => v.includes('Japanese script')));
});

test('findLocaleI18nViolations is clean for well-formed en copy', () => {
  const text = 'Farm list\nCreate a new farm\nNo items yet.';
  assert.deepEqual(findLocaleI18nViolations(text, 'en'), []);
});

test('findLocaleI18nViolations expects Devanagari for in locale body', () => {
  const englishOnly = 'Farm list\nCreate a new farm\nNo items yet.';
  const violations = findLocaleI18nViolations(englishOnly, 'in');
  assert.ok(violations.some((v) => v.includes('Devanagari')));
});
