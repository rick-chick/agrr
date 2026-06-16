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

const INTERACTION_RULES_CATALOG_KEYS = [
  'interaction_rules.form.rule_type_codes.continuous_cultivation',
  'interaction_rules.show.direction'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('interaction rules i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of INTERACTION_RULES_CATALOG_KEYS) {
        it(`defines ${key} as human-readable text`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          const text = value as string;
          expect(text.length).toBeGreaterThan(0);
          expect(text).not.toBe(key);
          expect(text).not.toBe('continuous_cultivation');
          expect(text).not.toBe('interaction_rules.show.is_directional');
        });
      }
    });
  }
});
