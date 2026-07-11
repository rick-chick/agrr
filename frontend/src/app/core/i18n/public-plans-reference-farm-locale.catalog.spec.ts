import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { REFERENCE_FARM_CATALOG } from '../../domain/public-plans/reference-farm-catalog';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('public_plans.reference_farms i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const entry of REFERENCE_FARM_CATALOG) {
        const key = `public_plans.reference_farms.${entry.slug}`;
        it(`defines ${entry.slug}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('does not leave legacy Punjab stub label in in locale', () => {
    const farms = getNested(inLocale as JsonRecord, 'public_plans.reference_farms') as JsonRecord;
    const values = Object.values(farms);
    expect(values).not.toContain('Punjab');
  });
});
