import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  collectStaticTranslateKeysFromText,
  findMissingLocaleKeys,
  getNested,
  lineNumberForOffset,
  uniqueByLocaleAndKey
} from './check-hardcoded-i18n-lib.mjs';

test('getNested resolves dotted keys', () => {
  const catalog = { pages: { about: { title: 'About' } } };
  assert.equal(getNested(catalog, 'pages.about.title'), 'About');
  assert.equal(getNested(catalog, 'pages.about.missing'), undefined);
});

test('lineNumberForOffset counts newline boundaries', () => {
  const text = 'one\ntwo\nthree';
  assert.equal(lineNumberForOffset(text, 0), 1);
  assert.equal(lineNumberForOffset(text, 4), 2);
  assert.equal(lineNumberForOffset(text, 8), 3);
});

test('collectStaticTranslateKeysFromText finds translate pipe and instant keys', () => {
  const text = `
    <h1>{{ 'pages.about.heading' | translate }}</h1>
    const label = this.translate.instant('entrySchedule.title');
    const ignored = \`entrySchedule.\${suffix}\`;
  `;
  const keys = collectStaticTranslateKeysFromText(text, 'about.component.ts');
  assert.deepEqual(
    keys.map((row) => row.key),
    ['pages.about.heading', 'entrySchedule.title']
  );
  assert.equal(keys[0].line, 2);
});

test('findMissingLocaleKeys reports only absent locale entries', () => {
  const references = [
    { key: 'entrySchedule.title', file: 'a.ts', line: 1 },
    { key: 'entrySchedule.retry', file: 'a.ts', line: 2 }
  ];
  const catalogs = {
    ja: { entrySchedule: { title: 'タイトル' } },
    en: { entrySchedule: { title: 'Title', retry: 'Retry' } },
    in: { entrySchedule: { title: 'शीर्षक' } }
  };

  const missing = findMissingLocaleKeys(references, catalogs);
  assert.deepEqual(
    missing.map((row) => `${row.locale}:${row.key}`),
    ['in:entrySchedule.retry', 'ja:entrySchedule.retry']
  );
});

test('uniqueByLocaleAndKey deduplicates repeated locale/key pairs', () => {
  const rows = [
    { locale: 'ja', key: 'entrySchedule.title', file: 'a.ts', line: 1 },
    { locale: 'ja', key: 'entrySchedule.title', file: 'b.ts', line: 9 }
  ];
  assert.equal(uniqueByLocaleAndKey(rows).length, 1);
});
