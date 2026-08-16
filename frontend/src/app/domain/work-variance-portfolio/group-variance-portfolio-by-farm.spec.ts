import { describe, expect, it } from 'vitest';

import { groupVariancePortfolioByFarm } from './group-variance-portfolio-by-farm';
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
    weatherTriggerCount: 0,
    ...overrides
  };
}

describe('groupVariancePortfolioByFarm', () => {
  it('groups rows by farm preserving farm name and sorting plans by year desc then plan id', () => {
    const groups = groupVariancePortfolioByFarm([
      row({ farmId: 2, farmName: 'Farm B', planId: 30, planYear: 2025 }),
      row({ farmId: 1, farmName: 'Farm A', planId: 11, planYear: 2027 }),
      row({ farmId: 1, farmName: 'Farm A', planId: 10, planYear: 2026 })
    ]);

    expect(groups).toHaveLength(2);
    expect(groups[0]).toEqual({
      farmId: 1,
      farmName: 'Farm A',
      plans: [
        row({ farmId: 1, planId: 11, planYear: 2027 }),
        row({ farmId: 1, planId: 10, planYear: 2026 })
      ]
    });
    expect(groups[1]?.farmId).toBe(2);
  });
});
