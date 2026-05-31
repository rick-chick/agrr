import { describe, expect, it } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

const MASTER_INDEX_DESCRIPTION_KEYS = [
  'farms',
  'crops',
  'fertilizes',
  'pests',
  'pesticides',
  'agricultural_tasks',
  'interaction_rules'
] as const;

type IndexBundle = Record<
  (typeof MASTER_INDEX_DESCRIPTION_KEYS)[number],
  { index?: { description?: string } }
>;

/** Master list page subtitles use `<context>.index.description` in list components. */
describe('masters index.description translation files', () => {
  it('defines index.description for ja, en, and in', () => {
    for (const [name, bundle] of [
      ['ja', ja],
      ['en', en],
      ['in', inLocale]
    ] as const) {
      const locales = bundle as IndexBundle;
      for (const context of MASTER_INDEX_DESCRIPTION_KEYS) {
        expect(locales[context]?.index?.description, `${name}:${context}`).toBeTruthy();
      }
    }
  });
});
