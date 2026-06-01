import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { GANTT_I18N_KEYS, GANTT_I18N_KEY_PATHS } from './gantt-locale.keys';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by gantt-chart (template + presenter). */
const GANTT_KEYS = GANTT_I18N_KEY_PATHS;

/** English uses empty axis suffixes for year/month (e.g. "2026", "5"). */
const EN_ALLOW_EMPTY_KEYS = new Set<string>([
  GANTT_I18N_KEYS.labels.year,
  GANTT_I18N_KEYS.labels.month
]);

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('gantt i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of GANTT_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          if (name === 'en' && EN_ALLOW_EMPTY_KEYS.has(key)) {
            return;
          }
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
