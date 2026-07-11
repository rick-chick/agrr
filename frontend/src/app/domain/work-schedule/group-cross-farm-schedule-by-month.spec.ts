import { describe, expect, it } from 'vitest';
import type { TaskScheduleItem } from '../../models/plans/task-schedule';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import { groupCrossFarmScheduleByMonth } from './group-cross-farm-schedule-by-month';

function row(
  overrides: Partial<CrossFarmScheduleRow> & Pick<CrossFarmScheduleRow, 'item'>
): CrossFarmScheduleRow {
  return {
    farmId: 1,
    farmName: 'Farm A',
    planId: 9,
    planName: 'Plan A',
    fieldName: '圃場1',
    fieldCultivationId: 101,
    cropName: 'トマト',
    ...overrides
  };
}

function item(partial: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name'>): TaskScheduleItem {
  return partial as TaskScheduleItem;
}

describe('groupCrossFarmScheduleByMonth', () => {
  it('groups rows by year-month and sorts chronologically', () => {
    const groups = groupCrossFarmScheduleByMonth([
      row({
        item: item({ item_id: 2, name: '追肥', scheduled_date: '2026-07-05', status: 'planned' })
      }),
      row({
        item: item({ item_id: 1, name: '除草', scheduled_date: '2026-06-12', status: 'planned' })
      }),
      row({
        item: item({ item_id: 3, name: '灌水', scheduled_date: '2026-06-10', status: 'planned' })
      })
    ]);

    expect(groups.map((g) => g.monthKey)).toEqual(['2026-06', '2026-07']);
    expect(groups[0].rows.map((r) => r.item.item_id)).toEqual([3, 1]);
    expect(groups[1].rows.map((r) => r.item.item_id)).toEqual([2]);
  });

  it('skips rows without scheduled_date', () => {
    const groups = groupCrossFarmScheduleByMonth([
      row({
        item: item({ item_id: 1, name: '除草', scheduled_date: '2026-06-12', status: 'planned' })
      }),
      row({
        item: item({ item_id: 2, name: '未設定', scheduled_date: null, status: 'planned' })
      })
    ]);

    expect(groups).toHaveLength(1);
    expect(groups[0].monthKey).toBe('2026-06');
  });

  it('returns empty array for empty input', () => {
    expect(groupCrossFarmScheduleByMonth([])).toEqual([]);
  });
});
