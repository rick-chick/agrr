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

/** Toast copy that includes a name placeholder (ngx `{{name}}`). */
const TOAST_KEYS_WITH_NAME = [
  'deletion_undo.toast_message',
  'flash.farms.deleted',
  'flash.crops.deleted',
  'pesticides.undo.toast',
  'agricultural_tasks.undo.toast',
  'crops.undo.toast',
  'pests.undo.toast',
  'fertilizes.undo.toast',
  'farms.undo.toast',
  'fields.undo.toast',
  'interaction_rules.undo.toast',
  'plans.undo.toast',
  'plans.task_schedule_items.undo.toast'
] as const;

/** Static undo UI labels (no name interpolation). */
const STATIC_TOAST_KEYS = ['deletion_undo.undo_button', 'deletion_undo.close_button'] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('deletion undo toast i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of [...TOAST_KEYS_WITH_NAME, ...STATIC_TOAST_KEYS]) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }

      for (const key of TOAST_KEYS_WITH_NAME) {
        it(`${key} uses ngx placeholders not Rails %{name}`, () => {
          const value = getNested(catalog, key) as string;
          if (key === 'deletion_undo.toast_message') {
            expect(value).toContain('{{resource}}');
            expect(value).not.toMatch(/%\{resource\}/);
            return;
          }
          if (key === 'interaction_rules.undo.toast') {
            expect(value).toContain('{{source}}');
            expect(value).toContain('{{target}}');
            expect(value).not.toMatch(/%\{/);
            return;
          }
          expect(value).toContain('{{name}}');
          expect(value).not.toMatch(/%\{name\}/);
        });
      }

      for (const key of STATIC_TOAST_KEYS) {
        it(`${key} has no Rails-style placeholders`, () => {
          const value = getNested(catalog, key) as string;
          expect(value).not.toMatch(/%\{/);
        });
      }
    });
  }
});
