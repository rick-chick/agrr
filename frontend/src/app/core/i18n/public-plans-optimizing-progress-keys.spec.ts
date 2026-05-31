import { TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService, type TranslationObject } from '@ngx-translate/core';
import { describe, expect, it, beforeEach } from 'vitest';
import en from '../../../assets/i18n/en.json';
import inLocale from '../../../assets/i18n/in.json';
import ja from '../../../assets/i18n/ja.json';

const NGX_KEYS = [
  'public_plans.optimizing.crops_count',
  'public_plans.optimizing.progress.elapsed_time',
  'public_plans.optimizing.progress.elapsed_time_minute',
  'plans.optimizing.crops_count',
  'plans.optimizing.progress.elapsed_time',
  'plans.optimizing.progress.elapsed_time_minute'
] as const;

function bundleValue(bundle: Record<string, unknown>, dottedKey: string): string {
  const parts = dottedKey.split('.');
  let node: unknown = bundle;
  for (const part of parts) {
    if (node == null || typeof node !== 'object') {
      throw new Error(`missing ${dottedKey}`);
    }
    node = (node as Record<string, unknown>)[part];
  }
  if (typeof node !== 'string') {
    throw new Error(`not a string: ${dottedKey}`);
  }
  return node;
}

/** Angular translate pipe keys must use {{ param }}, not Rails %{param}. */
describe('public_plans / plans optimizing progress i18n', () => {
  for (const [localeId, bundle] of [
    ['en', en],
    ['ja', ja],
    ['in', inLocale]
  ] as const) {
    describe(localeId, () => {
      it.each(NGX_KEYS)('%s uses ngx-translate {{ }} placeholders', (key) => {
        const value = bundleValue(bundle as Record<string, unknown>, key);
        expect(value, key).not.toMatch(/%\{/);
        expect(value, key).toMatch(/\{\{\s*\w+\s*\}\}/);
      });
    });
  }

  describe('TranslateService interpolation (in locale elapsed_time)', () => {
    beforeEach(() => {
      TestBed.configureTestingModule({
        imports: [TranslateModule.forRoot()]
      });
      const translate = TestBed.inject(TranslateService);
      translate.setTranslation('in', inLocale as TranslationObject, true);
      translate.use('in');
    });

    it('replaces time in Hindi elapsed_time', () => {
      const translate = TestBed.inject(TranslateService);
      const text = translate.instant('public_plans.optimizing.progress.elapsed_time', {
        time: 12
      });
      expect(text).toBe('⏳ 12 सेकंड');
      expect(text).not.toContain('%{');
    });
  });
});
