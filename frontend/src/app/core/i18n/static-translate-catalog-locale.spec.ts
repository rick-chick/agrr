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

/** Static | translate keys reported missing by check-hardcoded-i18n (issue #633). */
const STATIC_TRANSLATE_CATALOG_KEYS = [
  'agricultural_tasks.edit.title_default',
  'agricultural_tasks.errors.invalid_id',
  'agricultural_tasks.show.task_type',
  'common.creating',
  'common.sending',
  'common.updating',
  'cookie_consent.accept',
  'cookie_consent.description_html',
  'cookie_consent.privacy_link_text',
  'cookie_consent.reject',
  'cookie_consent.title',
  'crops.setup_proposal_import.action',
  'crops.setup_proposal_import.choose_file',
  'crops.setup_proposal_import.clipboard_error',
  'crops.setup_proposal_import.invalid_json',
  'crops.setup_proposal_import.invalid_shape',
  'crops.setup_proposal_import.json_label',
  'crops.setup_proposal_import.json_placeholder',
  'crops.setup_proposal_import.lead',
  'crops.setup_proposal_import.paste_clipboard',
  'crops.setup_proposal_import.preview_title',
  'crops.setup_proposal_import.title',
  'crops.setup_proposal_import.validation_errors_title',
  'crops.show.reference_crop',
  'farms.map.default_name',
  'farms.new.form.coordinates_validation_error',
  'interaction_rules.errors.invalid_id',
  'pesticides.edit.title_default',
  'pesticides.fallback.crop',
  'pesticides.fallback.pest',
  'public_plans.create_failed',
  'public_plans.invalid_farm_id'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('static translate catalog (issue #633)', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of STATIC_TRANSLATE_CATALOG_KEYS) {
        it(`defines ${key} as human-readable text`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          const text = value as string;
          expect(text.length).toBeGreaterThan(0);
          expect(text).not.toBe(key);
          expect(text).not.toContain('agricultural_tasks.');
          expect(text).not.toContain('cookie_consent.');
          expect(text).not.toContain('pesticides.edit.');
        });
      }
    });
  }
});
