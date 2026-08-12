import { describe, expect, it } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import {
  buildFieldClimateLatestImplementation,
  buildFieldClimateWorkDayMarkers
} from './field-climate-work-records';

function record(
  overrides: Partial<WorkRecord> & Pick<WorkRecord, 'id' | 'actual_date' | 'name'>
): WorkRecord {
  return {
    cultivation_plan_id: 1,
    field_cultivation_id: 10,
    task_schedule_item_id: 5,
    agricultural_task_id: null,
    task_type: null,
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-01',
    updated_at: '2026-06-01',
    task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' },
    ...overrides
  };
}

describe('field-climate-work-records', () => {
  it('builds work day markers from records', () => {
    expect(
      buildFieldClimateWorkDayMarkers([
        record({ id: 1, actual_date: '2026-06-12', name: 'Weeding' })
      ])
    ).toEqual([
      {
        actualDate: '2026-06-12',
        name: 'Weeding',
        taskScheduleItemId: 5
      }
    ]);
  });

  it('builds latest implementation summary from variance map', () => {
    const latest = buildFieldClimateLatestImplementation(
      [record({ id: 1, actual_date: '2026-06-12', name: 'Weeding' })],
      new Map([[5, { deltaDays: 2, gddDelta: 10.5 }]])
    );

    expect(latest).toEqual({
      name: 'Weeding',
      deltaDaysLabel: '+2',
      gddDeltaLabel: '+10.5'
    });
  });
});
