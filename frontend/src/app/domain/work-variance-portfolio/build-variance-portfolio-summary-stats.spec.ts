import { describe, expect, it } from 'vitest';

import { buildVariancePortfolioSummaryStats } from './build-variance-portfolio-summary-stats';
import type { VariancePortfolioRow } from './variance-portfolio-row';

function row(overrides: Partial<VariancePortfolioRow> = {}): VariancePortfolioRow {
  return {
    farmId: 1,
    farmName: 'Farm A',
    planId: 10,
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

describe('buildVariancePortfolioSummaryStats', () => {
  it('sums variance counts across all plan rows', () => {
    expect(
      buildVariancePortfolioSummaryStats([
        row({
          unrecordedCount: 2,
          gddDelayCount: 1,
          thresholdExceededCount: 3,
          daysThresholdExceededCount: 4
        }),
        row({
          planId: 11,
          unrecordedCount: 1,
          gddDelayCount: 2,
          thresholdExceededCount: 1,
          daysThresholdExceededCount: 2
        })
      ])
    ).toEqual({
      unrecordedCount: 3,
      actionRequiredCount: 4,
      gddDelayCount: 3,
      daysThresholdExceededCount: 6
    });
  });
});
