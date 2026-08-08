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

/** Keys referenced by crop-list and crop-detail delete confirm dialogs. */
const CATALOG_KEYS = [
  'crops.index.delete_confirm_message',
  'crops.show.delete_confirm_message'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('crops delete confirm i18n catalog (crop-list / crop-detail)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CATALOG_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('ja messages mention stages, templates, and undo', () => {
    for (const key of CATALOG_KEYS) {
      const message = getNested(ja as JsonRecord, key) as string;
      expect(message).toMatch(/ステージ|テンプレ/);
      expect(message).toMatch(/元に戻す/);
    }
  });
});
