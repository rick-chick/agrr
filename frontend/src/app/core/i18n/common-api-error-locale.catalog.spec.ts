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

/** Keys returned by apiErrorI18nKey and shown via translate pipe on API failures. */
const COMMON_API_ERROR_KEYS = [
  'common.api_error.unauthorized',
  'common.api_error.forbidden',
  'common.api_error.not_found',
  'common.api_error.network',
  'common.api_error.not_migrated',
  'common.api_error.service_unavailable',
  'common.api_error.generic'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('common.api_error i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of COMMON_API_ERROR_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
