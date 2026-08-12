import { describe, expect, it } from 'vitest';

import { collectPlanTaskScheduleUnrecordedRows } from './collect-plan-task-schedule-unrecorded-rows';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';

function row(
  overrides: Partial<CrossFarmScheduleRow['item']> = {}
): CrossFarmScheduleRow {
  return {
    farmId: 0,
    farmName: '',
    planId: 7,
    planName: 'Plan',
    fieldId: 1,
    fieldName: 'Field A',
    cropName: 'Tomato',
    fieldCultivationId: 10,
    item: {
      item_id: 1,
      name: 'Weeding',
      scheduled_date: '2026-06-01',
      actualDate: null,
      deltaDays: null,
      gddTrigger: null,
      gddAtActual: null,
      gddDelta: null,
      status: 'planned',
      completed: false,
      details: {
        stageName: null,
        amount: null,
        amountUnit: null,
        masterDescription: null
      },
      ...overrides
    }
  };
}

describe('collectPlanTaskScheduleUnrecordedRows', () => {
  it('returns scheduled items without an actual date', () => {
    const rows = collectPlanTaskScheduleUnrecordedRows([
      row(),
      row({ item_id: 2, scheduled_date: '2026-06-02', actualDate: '2026-06-05', deltaDays: 3 })
    ]);

    expect(rows).toHaveLength(1);
    expect(rows[0].item.item_id).toBe(1);
  });

  it('excludes skipped and unscheduled items', () => {
    const rows = collectPlanTaskScheduleUnrecordedRows([
      row({ status: 'skipped' }),
      row({ item_id: 3, scheduled_date: null })
    ]);

    expect(rows).toHaveLength(0);
  });
});
