import { describe, expect, it } from 'vitest';
import {
  filterVarianceActionItemsOnGantt,
  uniqueFieldCultivationIds
} from './filter-variance-action-items';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

function actionItem(
  overrides: Partial<PlanVarianceActionItem> = {}
): PlanVarianceActionItem {
  return {
    item_id: 1,
    field_cultivation_id: 100,
    category: 'general',
    name: 'Weed',
    scheduled_date: '2026-06-01',
    actual_date: '2026-06-08',
    delta_days: 7,
    gdd_trigger: 100,
    gdd_at_actual: 110,
    gdd_delta: 10,
    exceedance_kind: 'days',
    ...overrides
  };
}

describe('filterVarianceActionItemsOnGantt', () => {
  it('keeps action items whose field cultivation exists on the gantt', () => {
    const items = [
      actionItem({ item_id: 1, field_cultivation_id: 100 }),
      actionItem({ item_id: 2, field_cultivation_id: 200 })
    ];
    const cultivations = [{ id: 100 } as { id: number }];

    expect(filterVarianceActionItemsOnGantt(items, cultivations as never)).toEqual([items[0]]);
  });

  it('returns empty when no cultivations match', () => {
    expect(
      filterVarianceActionItemsOnGantt([actionItem()], [{ id: 999 } as never])
    ).toEqual([]);
  });
});

describe('uniqueFieldCultivationIds', () => {
  it('deduplicates field cultivation ids preserving order', () => {
    const items = [
      actionItem({ field_cultivation_id: 100 }),
      actionItem({ item_id: 2, field_cultivation_id: 200 }),
      actionItem({ item_id: 3, field_cultivation_id: 100 })
    ];

    expect(uniqueFieldCultivationIds(items)).toEqual([100, 200]);
  });
});
