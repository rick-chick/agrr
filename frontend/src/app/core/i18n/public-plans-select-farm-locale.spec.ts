import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in public plan select-farm strings. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by public-plan wizard shell and farm selection heading. */
const WIZARD_SHELL_KEYS = [
  'public_plans.title',
  'public_plans.breadcrumb_root',
  'public_plans.select_farm.available_farms',
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord },
];

describe('public_plans wizard shell i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of WIZARD_SHELL_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }

      it('uses the same label for title and breadcrumb_root', () => {
        const title = getNested(catalog, 'public_plans.title') as string;
        const breadcrumb = getNested(catalog, 'public_plans.breadcrumb_root') as string;
        expect(title).toBe(breadcrumb);
      });

      it('matches entrySchedule.selectFarm for the farm selection heading', () => {
        const farmHeading = getNested(catalog, 'public_plans.select_farm.available_farms') as string;
        const entryScheduleHeading = getNested(catalog, 'entrySchedule.selectFarm') as string;
        expect(farmHeading).toBe(entryScheduleHeading);
      });
    });
  }

  it('uses English (not Japanese) for en locale wizard shell strings', () => {
    for (const key of WIZARD_SHELL_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in en.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale wizard shell strings', () => {
    for (const key of WIZARD_SHELL_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in in.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
