import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys rendered in the About page operator information section. */
const PAGES_ABOUT_OPERATOR_KEYS = [
  'pages.about.operator.title',
  'pages.about.operator.operator_name',
  'pages.about.operator.location',
  'pages.about.operator.initiative',
  'pages.about.operator.contact_form',
  'pages.about.operator.contact_html',
  'pages.about.operator.ads_notice_html',
  'pages.about.operator.privacy_link_text',
  'pages.about.operator.sources_and_updates'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('pages.about operator i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PAGES_ABOUT_OPERATOR_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
