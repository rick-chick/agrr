import { describe, expect, it } from 'vitest';
import { buildWorkHubOtherVariancePlanCounts } from './build-work-hub-other-variance-plan-counts';
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
    weatherTriggerCount: 0,
    ...overrides
  };
}

describe('buildWorkHubOtherVariancePlanCounts', () => {
  it('counts other variance plans excluding the representative plan', () => {
    const counts = buildWorkHubOtherVariancePlanCounts(
      [
        row({ farmId: 1, planId: 9, thresholdExceededCount: 1 }),
        row({ farmId: 1, planId: 10, unrecordedCount: 2 }),
        row({ farmId: 1, planId: 11, gddDelayCount: 1 }),
        row({ farmId: 2, planId: 20, thresholdExceededCount: 1 }),
        row({ farmId: 2, planId: 21, unrecordedCount: 1 })
      ],
      [
        { farmId: 1, planId: 9 },
        { farmId: 2, planId: 20 }
      ]
    );

    expect(counts.get(1)).toBe(2);
    expect(counts.get(2)).toBe(1);
  });

  it('returns zero when representative plan is missing', () => {
    const counts = buildWorkHubOtherVariancePlanCounts(
      [row({ farmId: 1, planId: 10, unrecordedCount: 1 })],
      [{ farmId: 1, planId: null }]
    );

    expect(counts.get(1)).toBe(0);
  });
});
