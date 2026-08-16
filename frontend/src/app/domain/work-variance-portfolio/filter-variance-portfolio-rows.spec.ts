import { describe, expect, it } from 'vitest';

import { filterVariancePortfolioRows } from './filter-variance-portfolio-rows';
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

describe('filterVariancePortfolioRows', () => {
  const rows = [
    row({ farmId: 1, planId: 10, planYear: 2026, status: 'completed' }),
    row({ farmId: 1, planId: 11, planYear: 2027, status: 'pending' }),
    row({ farmId: 2, farmName: 'Farm B', planId: 20, planYear: 2026, status: 'optimizing' })
  ];

  it('returns all rows when filters are empty', () => {
    expect(
      filterVariancePortfolioRows(rows, { farmId: null, status: null, planYear: null })
    ).toEqual(rows);
  });

  it('filters by farmId', () => {
    expect(filterVariancePortfolioRows(rows, { farmId: 2, status: null, planYear: null })).toEqual([
      rows[2]
    ]);
  });

  it('filters by status', () => {
    expect(
      filterVariancePortfolioRows(rows, { farmId: null, status: 'pending', planYear: null })
    ).toEqual([rows[1]]);
  });

  it('filters by planYear', () => {
    expect(
      filterVariancePortfolioRows(rows, { farmId: null, status: null, planYear: 2027 })
    ).toEqual([rows[1]]);
  });

  it('applies all filters together', () => {
    expect(
      filterVariancePortfolioRows(rows, { farmId: 1, status: 'completed', planYear: 2026 })
    ).toEqual([rows[0]]);
  });
});
