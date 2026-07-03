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

/** Keys referenced by plan-detail, plan-plan-context-header, and climate placeholder. */
const PLANS_DETAIL_KEYS = [
  'plans.detail.select_cultivation_hint',
  'plans.show.page_title',
  'plans.show.back_to_list',
  'plans.show.open_work',
  'plans.show.nav.aria_label',
  'plans.show.nav.workbench',
  'plans.show.nav.task_schedule'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('plans.detail i18n catalog', () => {
  it('defines distinct non-English placeholders for ja and in', () => {
    const enValue = getNested(en as JsonRecord, PLANS_DETAIL_KEYS[0]) as string;
    const jaValue = getNested(ja as JsonRecord, PLANS_DETAIL_KEYS[0]) as string;
    const inValue = getNested(inLocale as JsonRecord, PLANS_DETAIL_KEYS[0]) as string;

    expect(jaValue).not.toBe(enValue);
    expect(inValue).not.toBe(enValue);
  });

  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PLANS_DETAIL_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
