import { describe, expect, it } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

type LocaleBundle = {
  plans?: {
    field_climate?: {
      chart?: { temperature?: string };
      base_temperature?: string;
    };
  };
  js?: {
    field_climate?: unknown;
  };
};

/** ngx-translate keys used by PlanFieldClimateComponent must live under plans, not js. */
describe('plans.field_climate translation files', () => {
  it('defines plans.field_climate for ja, en, and in', () => {
    for (const [name, bundle] of [
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const) {
      const locale = bundle as LocaleBundle;
      expect(locale.plans?.field_climate?.base_temperature, name).toBeTruthy();
      expect(locale.plans?.field_climate?.chart?.temperature, name).toBeTruthy();
      expect(locale.js?.field_climate, `${name} js.field_climate`).toBeUndefined();
    }
  });
});
