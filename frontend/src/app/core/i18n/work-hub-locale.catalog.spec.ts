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

/** Keys referenced by work-hub and navbar work log link. */
const WORK_HUB_I18N_KEYS = [
  'nav.work_log',
  'work.hub.title',
  'work.hub.subtitle',
  'work.hub.error_subtitle',
  'work.hub.select_farm',
  'work.hub.no_farms',
  'work.hub.no_farms_hint',
  'work.hub.create_farm_link',
  'work.hub.creating_plan',
  'work.hub.creating_plan_for',
  'work.hub.farm_meta',
  'work.hub.open_work',
  'work.hub.start_recording',
  'work.hub.no_fields_warning',
  'work.hub.register_fields_link',
  'work.hub.retry'
] as const;

describe('work hub i18n catalog', () => {
  it.each([
    ['ja', ja],
    ['en', en],
    ['in', inLocale]
  ] as const)('defines work hub keys in %s', (_label, locale) => {
    for (const key of WORK_HUB_I18N_KEYS) {
      const value = getNested(locale as JsonRecord, key);
      expect(typeof value).toBe('string');
      expect((value as string).length).toBeGreaterThan(0);
    }
  });
});
