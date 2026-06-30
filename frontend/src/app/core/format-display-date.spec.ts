import { describe, expect, it } from 'vitest';
import { appLangToBcp47, formatIsoDateForDisplay } from './format-display-date';

describe('formatIsoDateForDisplay', () => {
  it('formats ISO dates for Japanese locale', () => {
    expect(formatIsoDateForDisplay('2026-06-25', 'ja')).toBe('2026年6月25日');
  });

  it('formats ISO dates for English locale', () => {
    expect(formatIsoDateForDisplay('2026-06-25', 'en')).toBe('June 25, 2026');
  });

  it('returns original string when not ISO date', () => {
    expect(formatIsoDateForDisplay('invalid', 'ja')).toBe('invalid');
  });
});

describe('appLangToBcp47', () => {
  it('maps app languages to BCP 47 tags', () => {
    expect(appLangToBcp47('ja')).toBe('ja-JP');
    expect(appLangToBcp47('en')).toBe('en-US');
    expect(appLangToBcp47('in')).toBe('hi-IN');
  });
});
