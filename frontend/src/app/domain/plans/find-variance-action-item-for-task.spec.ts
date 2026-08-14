import { describe, expect, it } from 'vitest';

import { findVarianceActionItemForTask } from './find-variance-action-item-for-task';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

const actionItem: PlanVarianceActionItem = {
  item_id: 42,
  field_cultivation_id: 10,
  category: 'general',
  name: '追肥',
  scheduled_date: '2026-06-01',
  actual_date: '2026-06-10',
  delta_days: 5,
  gdd_trigger: 100,
  gdd_at_actual: 120,
  gdd_delta: 15,
  exceedance_kind: 'both'
};

describe('findVarianceActionItemForTask', () => {
  it('returns the matching action item by task schedule item id', () => {
    expect(findVarianceActionItemForTask(42, [actionItem])).toEqual(actionItem);
  });

  it('returns null when no item matches', () => {
    expect(findVarianceActionItemForTask(99, [actionItem])).toBeNull();
  });
});
