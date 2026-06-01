import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import { LANDING_DEMO_I18N_KEYS } from '../../domain/plans/landing-demo-i18n.keys';

type JsonRecord = Record<string, unknown>;

function getNested(obj: JsonRecord, path: string): unknown {
  return path.split('.').reduce<unknown>((current, key) => {
    if (current == null || typeof current !== 'object') return undefined;
    return (current as JsonRecord)[key];
  }, obj);
}

/** Keys referenced by HomeComponent (route `/`). */
const HOME_INDEX_KEYS = [
  'home.index.hero.title',
  'home.index.hero.subtitle_html',
  'home.index.hero.cta_scroll_demo',
  'home.index.hero.cta_footer_link',
  'home.index.demo.title',
  'home.index.demo.lead',
  'home.index.demo.disclaimer',
  'home.index.demo.badge',
  'home.index.demo.hints.drag',
  'home.index.demo.hints.tap',
  'home.index.demo.hints.add',
  'home.index.demo.cta_create',
  ...Object.values(LANDING_DEMO_I18N_KEYS),
  'home.index.features.title',
  'home.index.features.subtitle',
  'home.index.features.growth_prediction.title',
  'home.index.features.growth_prediction.description',
  'home.index.features.weather.title',
  'home.index.features.weather.description',
  'home.index.features.optimization.title',
  'home.index.features.optimization.description'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('home.index i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of HOME_INDEX_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
