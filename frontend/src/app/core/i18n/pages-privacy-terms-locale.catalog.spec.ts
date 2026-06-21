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

/** Keys rendered with contact_link interpolation on privacy/terms pages. */
const PAGES_PRIVACY_TERMS_KEYS = [
  'pages.privacy.section8.content_html',
  'pages.privacy.section8.contact_link_text',
  'pages.terms.article10.content_html',
  'pages.terms.article10.contact_link_text'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('pages.privacy / pages.terms contact_link i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PAGES_PRIVACY_TERMS_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }

      it('uses {{contact_link}} placeholder in content_html keys', () => {
        const privacyHtml = getNested(catalog, 'pages.privacy.section8.content_html') as string;
        const termsHtml = getNested(catalog, 'pages.terms.article10.content_html') as string;
        expect(privacyHtml).toContain('{{contact_link}}');
        expect(termsHtml).toContain('{{contact_link}}');
      });
    });
  }
});
