import { describe, expect, it } from 'vitest';
import { findVarianceActionItemForScheduleItem } from './find-variance-action-item-for-schedule-item';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

const actionItem: PlanVarianceActionItem = {
  item_id: 42,
  field_cultivation_id: 10,
  category: 'field_work',
  name: '追肥',
  scheduled_date: '2026-06-01',
  actual_date: '2026-06-08',
  delta_days: 7,
  gdd_trigger: 100,
  gdd_at_actual: 120,
  gdd_delta: 20,
  exceedance_kind: 'both'
};

describe('findVarianceActionItemForScheduleItem', () => {
  it('returns the matching action item by schedule item id', () => {
    expect(findVarianceActionItemForScheduleItem(42, [actionItem])).toBe(actionItem);
  });

  it('returns null when no action item matches', () => {
    expect(findVarianceActionItemForScheduleItem(99, [actionItem])).toBeNull();
  });
});
