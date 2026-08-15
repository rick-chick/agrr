import { describe, expect, it } from 'vitest';
import type { WorkHubFarmRow } from './work-hub-farm-row';
import { buildWorkHubPortfolioSummaryStats } from './build-work-hub-portfolio-summary-stats';

function farm(
  overrides: Partial<WorkHubFarmRow> & Pick<WorkHubFarmRow, 'farmId' | 'farmName'>
): WorkHubFarmRow {
  return {
    fieldCount: 1,
    totalArea: 100,
    hasValidFields: true,
    planId: 1,
    overdueCount: 0,
    todayCount: 0,
    unrecordedCount: 0,
    gddDelayCount: 0,
    daysExceedanceCount: 0,
    thresholdExceededCount: 0,
    ...overrides
  };
}

describe('buildWorkHubPortfolioSummaryStats', () => {
  it('sums unrecorded, action-required, gdd delay, and days threshold exceeded across farms', () => {
    const stats = buildWorkHubPortfolioSummaryStats([
      farm({
        farmId: 1,
        farmName: 'A',
        unrecordedCount: 2,
        thresholdExceededCount: 3,
        gddDelayCount: 1,
        daysExceedanceCount: 2
      }),
      farm({
        farmId: 2,
        farmName: 'B',
        unrecordedCount: 1,
        thresholdExceededCount: 2,
        gddDelayCount: 2,
        daysExceedanceCount: 1
      })
    ]);

    expect(stats).toEqual({
      unrecordedCount: 3,
      actionRequiredCount: 5,
      gddDelayCount: 3,
      daysThresholdExceededCount: 3
    });
  });

  it('returns zero totals for an empty farm list', () => {
    expect(buildWorkHubPortfolioSummaryStats([])).toEqual({
      unrecordedCount: 0,
      actionRequiredCount: 0,
      gddDelayCount: 0,
      daysThresholdExceededCount: 0
    });
  });
});
