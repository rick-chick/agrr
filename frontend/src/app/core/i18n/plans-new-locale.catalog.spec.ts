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

/** Keys referenced by plan-new.component template (page description and form). */
const PLAN_NEW_I18N_KEYS = [
  'plans.new.breadcrumb',
  'plans.new.title',
  'plans.new.subtitle',
  'plans.new.plan_name_label',
  'plans.new.plan_name_placeholder',
  'plans.new.farm_label',
  'plans.new.farm_hint',
  'plans.new.suggested_plan_name_hint',
  'plans.new.no_farms',
  'plans.new.no_farms_hint',
  'plans.new.create_farm_link',
  'plans.new.farm_limit_reached',
  'plans.new.farm_limit_hint',
  'plans.new.manage_farms_link',
  'plans.new.create_button',
  'plans.new.farm_option_with_fields',
  'plans.new.farm_option_no_fields',
  'plans.new.no_fields_warning',
  'plans.new.some_farms_no_fields_hint',
  'plans.new.register_fields_link',
  'plans.new.readiness.title',
  'plans.new.readiness.fields_ready',
  'plans.new.readiness.fields_missing',
  'plans.new.readiness.fields_action',
  'plans.new.readiness.weather_ready',
  'plans.new.readiness.weather_missing',
  'plans.new.readiness.weather_action',
  'plans.new.readiness.crops_ready',
  'plans.new.readiness.crops_missing',
  'plans.new.readiness.crops_incomplete',
  'plans.new.readiness.crops_action',
  'plans.new.readiness.crop_blueprint_action',
  'plans.new.readiness.load_error',
  'plans.new.readiness.retry'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

/** Locale-specific markers for "year" — form has no year input (issue #636). */
const YEAR_MARKERS: Record<string, RegExp> = {
  ja: /年/,
  en: /\byear\b/i,
  in: /वर्ष/
};

describe('plans.new i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of PLAN_NEW_I18N_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }

  it('title and subtitle do not mention year (no year field on /plans/new)', () => {
    for (const { name, catalog } of locales) {
      const title = getNested(catalog, 'plans.new.title') as string;
      const subtitle = getNested(catalog, 'plans.new.subtitle') as string;
      const marker = YEAR_MARKERS[name];
      expect(title, `${name} title`).not.toMatch(marker);
      expect(subtitle, `${name} subtitle`).not.toMatch(marker);
    }
  });
});
