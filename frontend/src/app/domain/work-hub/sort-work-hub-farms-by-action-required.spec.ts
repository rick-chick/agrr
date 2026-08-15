import { describe, expect, it } from 'vitest';
import type { WorkHubFarmRow } from './work-hub-farm-row';
import { sortWorkHubFarmsByActionRequired } from './sort-work-hub-farms-by-action-required';

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
    thresholdExceededCount: 0,
    ...overrides
  };
}

describe('sortWorkHubFarmsByActionRequired', () => {
  it('sorts farms by threshold exceeded count descending', () => {
    const sorted = sortWorkHubFarmsByActionRequired([
      farm({ farmId: 1, farmName: 'Low', thresholdExceededCount: 1 }),
      farm({ farmId: 2, farmName: 'High', thresholdExceededCount: 5 }),
      farm({ farmId: 3, farmName: 'Mid', thresholdExceededCount: 3 })
    ]);

    expect(sorted.map((row) => row.farmId)).toEqual([2, 3, 1]);
  });

  it('uses farm id ascending as tie-breaker when action-required counts match', () => {
    const sorted = sortWorkHubFarmsByActionRequired([
      farm({ farmId: 3, farmName: 'B', thresholdExceededCount: 2 }),
      farm({ farmId: 1, farmName: 'A', thresholdExceededCount: 2 }),
      farm({ farmId: 2, farmName: 'C', thresholdExceededCount: 2 })
    ]);

    expect(sorted.map((row) => row.farmId)).toEqual([1, 2, 3]);
  });
});
