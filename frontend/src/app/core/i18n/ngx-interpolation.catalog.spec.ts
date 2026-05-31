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

/** Keys passed to ngx-translate with `{ name: ... }` must use `{{name}}`, not Rails `%{name}`. */
const NGX_NAME_INTERPOLATION_KEYS = [
  'crops.edit.title',
  'pests.edit.title',
  'fertilizes.edit.title',
  'pesticides.edit.title',
  'agricultural_tasks.edit.title',
  'plans.task_schedules.title',
  'entrySchedule.viz.ganttAria'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('ngx-translate name interpolation catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of NGX_NAME_INTERPOLATION_KEYS) {
        it(`${key} uses {{name}} not %{name}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          const text = value as string;
          expect(text).toContain('{{name}}');
          expect(text).not.toMatch(/%\{name\}/);
        });
      }
    });
  }
});
