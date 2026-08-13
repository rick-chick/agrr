import { describe, expect, it } from 'vitest';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';
import { WorkRecord } from '../../models/plans/work-record';
import { findVarianceActionItemForRecord } from './find-variance-action-item-for-record';

function actionItem(
  overrides: Partial<PlanVarianceActionItem> & Pick<PlanVarianceActionItem, 'item_id'>
): PlanVarianceActionItem {
  return {
    field_cultivation_id: 100,
    category: 'general',
    name: 'Weeding',
    scheduled_date: '2026-06-01',
    actual_date: '2026-06-08',
    delta_days: 7,
    gdd_trigger: null,
    gdd_at_actual: null,
    gdd_delta: null,
    exceedance_kind: 'days',
    ...overrides
  };
}

function record(taskScheduleItemId: number | null): WorkRecord {
  return {
    id: 1,
    cultivation_plan_id: 7,
    field_cultivation_id: 100,
    task_schedule_item_id: taskScheduleItemId,
    agricultural_task_id: null,
    name: 'Weeding',
    task_type: null,
    actual_date: '2026-06-08',
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-08',
    updated_at: '2026-06-08',
    task_schedule_item:
      taskScheduleItemId != null
        ? { id: taskScheduleItemId, name: 'Weeding', scheduled_date: '2026-06-01' }
        : null
  };
}

describe('findVarianceActionItemForRecord', () => {
  it('returns the matching action item for schedule-linked records', () => {
    const items = [actionItem({ item_id: 11 }), actionItem({ item_id: 12, field_cultivation_id: 200 })];
    expect(findVarianceActionItemForRecord(record(11), items)).toEqual(items[0]);
  });

  it('returns null when the record is not schedule-linked', () => {
    expect(findVarianceActionItemForRecord(record(null), [actionItem({ item_id: 11 })])).toBeNull();
  });

  it('returns null when no action item matches the saved task', () => {
    expect(findVarianceActionItemForRecord(record(99), [actionItem({ item_id: 11 })])).toBeNull();
  });
});
