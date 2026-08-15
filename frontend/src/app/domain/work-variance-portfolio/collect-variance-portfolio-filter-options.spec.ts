import { describe, expect, it } from 'vitest';

import { collectVariancePortfolioFilterOptions } from './collect-variance-portfolio-filter-options';
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

describe('collectVariancePortfolioFilterOptions', () => {
  it('collects unique farms, statuses, and years sorted for filter controls', () => {
    expect(
      collectVariancePortfolioFilterOptions([
        row({ farmId: 2, farmName: 'Farm B', status: 'pending', planYear: 2027 }),
        row({ farmId: 1, farmName: 'Farm A', status: 'completed', planYear: 2026 }),
        row({ farmId: 1, planId: 11, status: 'completed', planYear: null })
      ])
    ).toEqual({
      farms: [
        { farmId: 1, farmName: 'Farm A' },
        { farmId: 2, farmName: 'Farm B' }
      ],
      statuses: ['completed', 'pending'],
      planYears: [2027, 2026]
    });
  });
});
