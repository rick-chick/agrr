import { describe, expect, it } from 'vitest';

import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';
import {
  HOME_DEMO_SECTION_I18N_KEYS,
  LANDING_DEMO_I18N_KEYS
} from '../../domain/plans/landing-demo-i18n.keys';
import { buildHomeDemoTitle } from './home-demo-title';

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
  'home.index.demo.schedule',
  'home.index.demo.preview',
  'home.index.demo.separator',
  'home.index.demo.hints_aria',
  'home.index.demo.disclaimer',
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
  it('composes Schedule · Preview title from locale parts (ja)', () => {
    const instant = (key: string, params?: Record<string, string>) => {
      let value = getNested(ja as JsonRecord, key) as string;
      if (params) {
        for (const [name, replacement] of Object.entries(params)) {
          value = value.replaceAll(`{{${name}}}`, replacement);
        }
      }
      return value;
    };
    expect(buildHomeDemoTitle({ instant })).toBe('スケジュール · プレビュー');
  });

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
