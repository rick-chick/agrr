import { describe, expect, it } from 'vitest';
import { planWorkRecordSavedPatch } from './plan-work-record-saved-view';
import { WorkRecord } from '../../models/plans/work-record';

const workRecord = (overrides: Partial<WorkRecord> = {}): WorkRecord => ({
  id: 1,
  cultivation_plan_id: 7,
  field_cultivation_id: null,
  task_schedule_item_id: null,
  agricultural_task_id: null,
  name: '除草',
  task_type: null,
  actual_date: '2026-06-25',
  amount: null,
  amount_unit: null,
  time_spent_minutes: null,
  notes: null,
  created_at: '2026-06-25',
  updated_at: '2026-06-25',
  task_schedule_item: null,
  ...overrides
});

describe('planWorkRecordSavedPatch', () => {
  it('stores recent ad hoc feedback for unscheduled saves', () => {
    expect(
      planWorkRecordSavedPatch({
        workRecord: workRecord({ name: '予定外除草' }),
        mode: 'create-adhoc'
      })
    ).toEqual({
      recentAdHocRecord: {
        name: '予定外除草',
        actualDate: '2026-06-25'
      },
      highlightedItemId: null
    });
  });

  it('highlights the schedule item after recording from item', () => {
    expect(
      planWorkRecordSavedPatch({
        workRecord: workRecord({ task_schedule_item_id: 11 }),
        mode: 'create-from-item'
      })
    ).toEqual({
      recentAdHocRecord: null,
      highlightedItemId: 11
    });
  });

  it('clears recent ad hoc feedback for other save modes', () => {
    expect(
      planWorkRecordSavedPatch({
        workRecord: workRecord(),
        mode: 'edit'
      })
    ).toEqual({
      recentAdHocRecord: null,
      highlightedItemId: null
    });
  });
});
