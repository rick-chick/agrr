import { describe, expect, it } from 'vitest';
import {
  appLangToBcp47,
  formatIsoDateForDisplay,
  formatIsoDateTimeForDisplay,
  formatIsoDayForDisplay,
  formatIsoMonthForDisplay
} from './format-display-date';

describe('formatIsoDayForDisplay', () => {
  it('formats ISO day for Japanese locale', () => {
    expect(formatIsoDayForDisplay('2026-06-25', 'ja')).toBe('25日');
  });

  it('formats ISO day for English locale', () => {
    expect(formatIsoDayForDisplay('2026-06-25', 'en')).toBe('25');
  });

  it('returns original string when not ISO date', () => {
    expect(formatIsoDayForDisplay('invalid', 'ja')).toBe('invalid');
  });
});

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

describe('formatIsoDateTimeForDisplay', () => {
  it('formats SQLite datetime for Japanese locale', () => {
    expect(formatIsoDateTimeForDisplay('2026-06-25 09:03:01', 'ja')).toBe('2026年6月25日 9:03');
  });

  it('formats SQLite datetime for English locale', () => {
    expect(formatIsoDateTimeForDisplay('2026-06-25 09:03:01', 'en')).toBe('June 25, 2026 at 9:03 AM');
  });

  it('formats date-only values like formatIsoDateForDisplay', () => {
    expect(formatIsoDateTimeForDisplay('2026-06-25', 'ja')).toBe('2026年6月25日');
  });

  it('returns original string when not parseable', () => {
    expect(formatIsoDateTimeForDisplay('invalid', 'ja')).toBe('invalid');
  });
});

describe('formatIsoDayForDisplay', () => {
  it('formats ISO day for Japanese locale', () => {
    expect(formatIsoDayForDisplay('2026-06-25', 'ja')).toBe('25日');
  });

  it('formats ISO day for English locale', () => {
    expect(formatIsoDayForDisplay('2026-06-25', 'en')).toBe('25');
  });

  it('returns original string when not ISO date', () => {
    expect(formatIsoDayForDisplay('invalid', 'ja')).toBe('invalid');
  });
});

describe('formatIsoMonthForDisplay', () => {
  it('formats ISO year-month for Japanese locale', () => {
    expect(formatIsoMonthForDisplay('2026-07', 'ja')).toBe('2026年7月');
  });

  it('formats ISO year-month for English locale', () => {
    expect(formatIsoMonthForDisplay('2026-07', 'en')).toBe('July 2026');
  });

  it('returns original string when not ISO year-month', () => {
    expect(formatIsoMonthForDisplay('invalid', 'ja')).toBe('invalid');
  });
});

describe('appLangToBcp47', () => {
  it('maps app languages to BCP 47 tags', () => {
    expect(appLangToBcp47('ja')).toBe('ja-JP');
    expect(appLangToBcp47('en')).toBe('en-US');
    expect(appLangToBcp47('in')).toBe('hi-IN');
  });
});
