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

/** Keys referenced by contact-form component, domain validation, and send use case. */
const CONTACT_FORM_KEYS = [
  'contact_form.name',
  'contact_form.email',
  'contact_form.subject',
  'contact_form.message',
  'contact_form.submit',
  'contact_form.success.message',
  'contact_form.success.toast',
  'contact_form.errors.send_failed',
  'contact_form.errors.validation_failed',
  'contact_form.validation.message_required',
  'contact_form.validation.message_too_long',
  'contact_form.validation.name_too_long',
  'contact_form.validation.subject_too_long',
  'contact_form.validation.email_required',
  'contact_form.validation.email_invalid'
] as const;

const locales: { name: string; catalog: JsonRecord }[] = [
  { name: 'ja', catalog: ja as JsonRecord },
  { name: 'en', catalog: en as JsonRecord },
  { name: 'in', catalog: inLocale as JsonRecord }
];

describe('contact_form i18n catalog', () => {
  for (const { name, catalog } of locales) {
    describe(name, () => {
      for (const key of CONTACT_FORM_KEYS) {
        it(`defines ${key}`, () => {
          const value = getNested(catalog, key);
          expect(typeof value).toBe('string');
          expect((value as string).trim().length).toBeGreaterThan(0);
        });
      }
    });
  }
});
