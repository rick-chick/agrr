import { describe, expect, it } from 'vitest';
import {
  computeWorkRecordAmountDiff,
  isAmountTrackedScheduleCategory,
  parseWorkRecordAmount
} from './work-record-amount-diff';

describe('parseWorkRecordAmount', () => {
  it('parses numeric strings', () => {
    expect(parseWorkRecordAmount('10.5')).toBe(10.5);
  });

  it('returns null for empty or invalid values', () => {
    expect(parseWorkRecordAmount('')).toBeNull();
    expect(parseWorkRecordAmount('abc')).toBeNull();
  });
});

describe('isAmountTrackedScheduleCategory', () => {
  it('returns true for fertilizer and pest_control', () => {
    expect(isAmountTrackedScheduleCategory('fertilizer')).toBe(true);
    expect(isAmountTrackedScheduleCategory('pest_control')).toBe(true);
  });

  it('returns false for general and null', () => {
    expect(isAmountTrackedScheduleCategory('general')).toBe(false);
    expect(isAmountTrackedScheduleCategory(null)).toBe(false);
  });
});

describe('computeWorkRecordAmountDiff', () => {
  it('computes diff between planned and actual amounts', () => {
    expect(computeWorkRecordAmountDiff('10', '12', 'kg')).toEqual({
      planned: 10,
      actual: 12,
      diff: 2,
      unit: 'kg'
    });
  });

  it('returns null when both amounts are empty', () => {
    expect(computeWorkRecordAmountDiff('', '', 'kg')).toBeNull();
  });

  it('returns partial diff when only planned amount is set', () => {
    expect(computeWorkRecordAmountDiff('5', '', 'L')).toEqual({
      planned: 5,
      actual: null,
      diff: null,
      unit: 'L'
    });
  });
});
