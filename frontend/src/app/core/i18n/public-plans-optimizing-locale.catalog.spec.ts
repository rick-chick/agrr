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

const PUBLIC_PLANS_OPTIMIZING_KEYS = [
  'public_plans.optimizing.status_badge',
  'public_plans.optimizing.status_badge_failed',
  'public_plans.optimizing.error.title',
  'models.cultivation_plan.phases.completed',
  'models.cultivation_plan.phase_failed.default'
] as const;

describe('public-plans optimizing locale catalog (#19)', () => {
  for (const [localeId, bundle] of [
    ['ja', ja],
    ['en', en],
    ['in', inLocale]
  ] as const) {
    describe(localeId, () => {
      it.each(PUBLIC_PLANS_OPTIMIZING_KEYS)('%s is defined', (key) => {
        const value = getNested(bundle as JsonRecord, key);
        expect(value, key).toBeTruthy();
        expect(typeof value, key).toBe('string');
        expect(String(value), key).not.toMatch(/^models\./);
      });
    });
  }
});
