import { describe, expect, it } from 'vitest';
import { variancePortfolioRowNeedsAttention } from './variance-portfolio-row-needs-attention';
import type { VariancePortfolioRow } from './variance-portfolio-row';

function row(overrides: Partial<VariancePortfolioRow> = {}): VariancePortfolioRow {
  return {
    farmId: 1,
    farmName: 'Farm A',
    planId: 9,
    planYear: 2026,
    status: 'completed',
    unrecordedCount: 0,
    gddDelayCount: 0,
    thresholdExceededCount: 0,
    daysThresholdExceededCount: 0,
    carryoverNotImported: false,
    ...overrides
  };
}

describe('variancePortfolioRowNeedsAttention', () => {
  it('returns false when all variance counts are zero', () => {
    expect(variancePortfolioRowNeedsAttention(row())).toBe(false);
  });

  it('returns true when any variance count is positive', () => {
    expect(variancePortfolioRowNeedsAttention(row({ unrecordedCount: 1 }))).toBe(true);
    expect(variancePortfolioRowNeedsAttention(row({ gddDelayCount: 1 }))).toBe(true);
    expect(variancePortfolioRowNeedsAttention(row({ thresholdExceededCount: 1 }))).toBe(true);
    expect(variancePortfolioRowNeedsAttention(row({ daysThresholdExceededCount: 1 }))).toBe(true);
  });
});
