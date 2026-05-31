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

/** Keys returned in API `toast_message` or shown on the undo toast UI. */
const DELETION_UNDO_TOAST_CATALOG_KEYS = [
  'deletion_undo.toast_message',
  'deletion_undo.undo_button',
  'deletion_undo.close_button',
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

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('deletion undo toast i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of DELETION_UNDO_TOAST_CATALOG_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).length).toBeGreaterThan(0);
        });
      }
    });
  }
});
