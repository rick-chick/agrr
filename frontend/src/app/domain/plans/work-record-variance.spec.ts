import { describe, expect, it } from 'vitest';
import { WorkRecord } from '../../models/plans/work-record';
import {
  averageWorkRecordDeltaDays,
  deltaDaysBetween,
  workRecordDeltaDays,
  workRecordScheduledDate
} from './work-record-variance';

function record(
  overrides: Partial<WorkRecord> & Pick<WorkRecord, 'id' | 'actual_date'>
): WorkRecord {
  return {
    cultivation_plan_id: 1,
    field_cultivation_id: 10,
    task_schedule_item_id: null,
    agricultural_task_id: null,
    name: 'Weeding',
    task_type: null,
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-01',
    updated_at: '2026-06-01',
    task_schedule_item: null,
    ...overrides
  };
}

describe('work-record-variance', () => {
  it('computes positive delta when actual is later than scheduled', () => {
    expect(deltaDaysBetween('2026-06-10', '2026-06-12')).toBe(2);
  });

  it('computes negative delta when actual is earlier than scheduled', () => {
    expect(deltaDaysBetween('2026-06-12', '2026-06-10')).toBe(-2);
  });

  it('returns scheduled date from linked task schedule item', () => {
    const scheduled = workRecordScheduledDate(
      record({
        id: 1,
        actual_date: '2026-06-12',
        task_schedule_item_id: 5,
        task_schedule_item: { id: 5, name: 'Weeding', scheduled_date: '2026-06-10' }
      })
    );
    expect(scheduled).toBe('2026-06-10');
  });

  it('returns null delta for ad hoc records without schedule link', () => {
    expect(
      workRecordDeltaDays(
        record({
          id: 1,
          actual_date: '2026-06-12'
        })
      )
    ).toBeNull();
  });

  it('averages delta days for schedule-linked records in a month group', () => {
    const average = averageWorkRecordDeltaDays([
      record({
        id: 1,
        actual_date: '2026-06-12',
        task_schedule_item_id: 1,
        task_schedule_item: { id: 1, name: 'A', scheduled_date: '2026-06-10' }
      }),
      record({
        id: 2,
        actual_date: '2026-06-14',
        task_schedule_item_id: 2,
        task_schedule_item: { id: 2, name: 'B', scheduled_date: '2026-06-10' }
      }),
      record({
        id: 3,
        actual_date: '2026-06-11'
      })
    ]);

    expect(average).toBe(3);
  });
});
