import { describe, expect, it } from 'vitest';
import { buildWorkHubVarianceCoverageStats } from './build-work-hub-variance-coverage-stats';
import type { VariancePortfolioRow } from '../work-variance-portfolio/variance-portfolio-row';

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

describe('buildWorkHubVarianceCoverageStats', () => {
  it('counts unique farms and plans that need variance attention', () => {
    const stats = buildWorkHubVarianceCoverageStats([
      row({ farmId: 1, planId: 9, thresholdExceededCount: 2 }),
      row({ farmId: 1, planId: 10, unrecordedCount: 1 }),
      row({ farmId: 2, planId: 20, gddDelayCount: 1 }),
      row({ farmId: 3, planId: 30 })
    ]);

    expect(stats).toEqual({ farmCount: 2, planCount: 3 });
  });

  it('returns zero counts when no rows need attention', () => {
    expect(buildWorkHubVarianceCoverageStats([row(), row({ farmId: 2, planId: 11 })])).toEqual({
      farmCount: 0,
      planCount: 0
    });
  });
});
