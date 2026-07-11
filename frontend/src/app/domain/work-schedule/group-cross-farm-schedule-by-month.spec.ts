import { describe, expect, it } from 'vitest';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import { groupCrossFarmScheduleRowsByMonth } from './group-cross-farm-schedule-by-month';

function row(
  overrides: Partial<CrossFarmScheduleRow> & {
    item_id: number;
    scheduled_date: string;
    name: string;
  }
): CrossFarmScheduleRow {
  const { item_id, scheduled_date, name, ...rest } = overrides;
  return {
    item: {
      item_id,
      name,
      scheduled_date,
      status: 'planned'
    } as CrossFarmScheduleRow['item'],
    farmId: 1,
    farmName: 'Farm A',
    planId: 9,
    planName: 'Plan A',
    fieldName: '圃場1',
    fieldCultivationId: 101,
    cropName: 'トマト',
    ...rest
  };
}

describe('groupCrossFarmScheduleRowsByMonth', () => {
  it('groups rows by year-month and sorts chronologically', () => {
    const groups = groupCrossFarmScheduleRowsByMonth([
      row({ item_id: 1, scheduled_date: '2026-07-05', name: '除草' }),
      row({ item_id: 2, scheduled_date: '2026-06-12', name: '追肥' }),
      row({ item_id: 3, scheduled_date: '2026-06-10', name: '播種' })
    ]);

    expect(groups.map((g) => g.monthKey)).toEqual(['2026-06', '2026-07']);
    expect(groups[0].rows.map((r) => r.item.item_id)).toEqual([3, 2]);
    expect(groups[1].rows.map((r) => r.item.item_id)).toEqual([1]);
  });

  it('skips rows without scheduled_date', () => {
    const groups = groupCrossFarmScheduleRowsByMonth([
      row({ item_id: 1, scheduled_date: '2026-06-10', name: '除草' }),
      {
        ...row({ item_id: 2, scheduled_date: '2026-06-12', name: '追肥' }),
        item: {
          ...row({ item_id: 2, scheduled_date: '2026-06-12', name: '追肥' }).item,
          scheduled_date: null
        }
      }
    ]);

    expect(groups).toHaveLength(1);
    expect(groups[0].rows).toHaveLength(1);
    expect(groups[0].rows[0].item.item_id).toBe(1);
  });

  it('returns empty array for no rows', () => {
    expect(groupCrossFarmScheduleRowsByMonth([])).toEqual([]);
  });
});
