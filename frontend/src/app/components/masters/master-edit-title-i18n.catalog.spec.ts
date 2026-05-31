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

/** Edit screens pass `name` to ngx-translate; catalog must use `{{name}}`, not Rails `%{name}`. */
const MASTER_EDIT_TITLE_KEYS = [
  'crops.edit.title',
  'pests.edit.title',
  'fertilizes.edit.title',
  'pesticides.edit.title',
  'agricultural_tasks.edit.title'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('Master edit title i18n (ngx-translate placeholders)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of MASTER_EDIT_TITLE_KEYS) {
        it(`${key} interpolates name with {{name}}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          const title = value as string;
          expect(title).toContain('{{name}}');
          expect(title).not.toMatch(/%\{name\}/);
        });
      }
    });
  }
});
