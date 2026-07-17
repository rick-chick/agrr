import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

/** CJK characters that should not appear in en/in navbar strings. */
const JAPANESE_UI = /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/;

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by app-navbar and app-nav-dropdown. */
const NAV_KEYS = [
  'nav.main',
  'nav.open_menu',
  'nav.close_menu',
  'nav.plan',
  'nav.menu_masters',
  'nav.new_plan',
  'nav.reports',
  'nav.api_keys',
  'nav.menu_more',
  'nav.farms',
  'nav.crops',
  'nav.fertilizes',
  'nav.pests',
  'nav.pesticides',
  'nav.agricultural_tasks',
  'nav.interaction_rules',
  'nav.about',
  'nav.contact',
  'nav.privacy',
  'nav.terms',
  'nav.login',
  'nav.logout',
  'status.checking',
  'footer.about',
  'footer.terms',
  'footer.privacy',
  'footer.contact',
  'footer.copyright'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('nav i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of NAV_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('uses English (not Japanese) for en locale nav strings', () => {
    for (const key of NAV_KEYS) {
      const value = getNested(en as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in en.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });

  it('uses Hindi (not Japanese) for in locale nav strings', () => {
    for (const key of NAV_KEYS) {
      const value = getNested(inLocale as JsonRecord, key) as string;
      expect(value, `unexpected Japanese in in.json ${key}: ${value}`).not.toMatch(JAPANESE_UI);
    }
  });
});
