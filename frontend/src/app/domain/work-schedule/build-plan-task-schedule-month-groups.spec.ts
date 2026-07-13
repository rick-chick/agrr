import { describe, expect, it } from 'vitest';
import type {
  PlanFieldSchedule,
  PlanSchedulePlanInfo,
  PlanTaskScheduleItem
} from './plan-schedule-snapshot';
import { emptyPlanTaskScheduleItemDetails } from './plan-schedule-snapshot';
import { buildPlanTaskScheduleMonthGroups, buildPlanTaskScheduleMonthGroupsFromRows } from './build-plan-task-schedule-month-groups';
import { flattenPlanTaskSchedule } from './flatten-plan-task-schedule';

function task(
  overrides: Partial<PlanTaskScheduleItem> & Pick<PlanTaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): PlanTaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    status: overrides.status ?? 'planned',
    completed: overrides.completed ?? false,
    details: overrides.details ?? emptyPlanTaskScheduleItemDetails
  };
}

function field(
  overrides: Partial<PlanFieldSchedule> & Pick<PlanFieldSchedule, 'field_cultivation_id'>
): PlanFieldSchedule {
  return {
    id: overrides.id ?? overrides.field_cultivation_id,
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

describe('buildPlanTaskScheduleMonthGroups', () => {
  const fields = [
    field({
      id: 1,
      field_cultivation_id: 10,
      name: 'North',
      schedules: {
        general: [task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10' })],
        fertilizer: []
      }
    }),
    field({
      id: 2,
      field_cultivation_id: 20,
      name: 'South',
      crop_name: 'Carrot',
      schedules: {
        general: [task({ item_id: 2, name: 'Harvest', scheduled_date: '2026-07-05' })],
        fertilizer: []
      }
    })
  ];

  it('groups rows by month in chronological order', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, null, null, '2026-01-01');

    expect(groups.map((group) => group.monthKey)).toEqual(['2026-06', '2026-07']);
    expect(groups[0]?.rows.map((row) => row.item.name)).toEqual(['Weeding']);
    expect(groups[1]?.rows.map((row) => row.item.name)).toEqual(['Harvest']);
  });

  it('filters rows by plan field id', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, 2, null, '2026-01-01');

    expect(groups).toHaveLength(1);
    expect(groups[0]?.monthKey).toBe('2026-07');
    expect(groups[0]?.rows[0]?.fieldName).toBe('South');
  });

  it('filters rows by field cultivation id when deep-linked', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, null, 20, '2026-01-01');

    expect(groups).toHaveLength(1);
    expect(groups[0]?.monthKey).toBe('2026-07');
    expect(groups[0]?.rows[0]?.fieldName).toBe('South');
  });

  it('filters rows by fromDate', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, null, null, '2026-06-15');

    expect(groups).toHaveLength(1);
    expect(groups[0]?.monthKey).toBe('2026-07');
    expect(groups[0]?.rows.map((row) => row.item.name)).toEqual(['Harvest']);
  });

  it('buildPlanTaskScheduleMonthGroupsFromRows matches full builder for same rows', () => {
    const rows = flattenPlanTaskSchedule(plan, fields);
    const fromRows = buildPlanTaskScheduleMonthGroupsFromRows(rows, null, null, '2026-01-01');
    const fromFields = buildPlanTaskScheduleMonthGroups(plan, fields, null, null, '2026-01-01');

    expect(fromRows).toEqual(fromFields);
  });
});
