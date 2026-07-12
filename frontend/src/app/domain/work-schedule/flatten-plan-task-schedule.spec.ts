import { describe, expect, it } from 'vitest';
import type {
  PlanFieldSchedule,
  PlanSchedulePlanInfo,
  PlanTaskScheduleItem
} from './plan-schedule-snapshot';
import { flattenPlanTaskSchedule } from './flatten-plan-task-schedule';

function task(
  overrides: Partial<PlanTaskScheduleItem> & Pick<PlanTaskScheduleItem, 'item_id' | 'name'>
): PlanTaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date ?? null,
    status: overrides.status ?? 'planned'
  };
}

function field(
  overrides: Partial<PlanFieldSchedule> & Pick<PlanFieldSchedule, 'field_cultivation_id'>
): PlanFieldSchedule {
  return {
    name: overrides.name ?? 'Field A',
    crop_name: overrides.crop_name ?? 'Tomato',
    field_cultivation_id: overrides.field_cultivation_id,
    schedules: overrides.schedules ?? { general: [], fertilizer: [] }
  };
}

const plan: PlanSchedulePlanInfo = {
  id: 7,
  name: 'Main Plan'
};

describe('flattenPlanTaskSchedule', () => {
  it('flattens scheduled general and fertilizer tasks with field metadata', () => {
    const rows = flattenPlanTaskSchedule(plan, [
      field({
        field_cultivation_id: 10,
        schedules: {
          general: [task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10' })],
          fertilizer: [task({ item_id: 2, name: 'Top dress', scheduled_date: '2026-06-12' })]
        }
      })
    ]);

    expect(rows).toHaveLength(2);
    expect(rows[0]?.item.name).toBe('Weeding');
    expect(rows[0]?.planId).toBe(7);
    expect(rows[0]?.fieldCultivationId).toBe(10);
    expect(rows[0]?.fieldName).toBe('Field A');
    expect(rows[0]?.cropName).toBe('Tomato');
    expect(rows.map((row) => row.item.name)).toEqual(['Weeding', 'Top dress']);
  });

  it('skips tasks without scheduled_date', () => {
    const rows = flattenPlanTaskSchedule(plan, [
      field({
        field_cultivation_id: 10,
        schedules: {
          general: [task({ item_id: 1, name: 'Pending', scheduled_date: null })],
          fertilizer: []
        }
      })
    ]);

    expect(rows).toEqual([]);
  });
});
