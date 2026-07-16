import { describe, expect, it } from 'vitest';

import { parseOptionalNumber } from './parse-optional-number';

describe('parseOptionalNumber', () => {
  it('returns null for nullish and empty string', () => {
    expect(parseOptionalNumber(null)).toBeNull();
    expect(parseOptionalNumber(undefined)).toBeNull();
    expect(parseOptionalNumber('')).toBeNull();
  });

  it('returns finite numbers for numeric and numeric string values', () => {
    expect(parseOptionalNumber(12)).toBe(12);
    expect(parseOptionalNumber('12')).toBe(12);
    expect(parseOptionalNumber('12.5')).toBe(12.5);
  });

  it('returns null for non-numeric values', () => {
    expect(parseOptionalNumber('abc')).toBeNull();
    expect(parseOptionalNumber(Number.NaN)).toBeNull();
  });
});
