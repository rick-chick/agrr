import { describe, expect, it } from 'vitest';
import type { FieldSchedule, PlanInfo, TaskScheduleItem } from '../../models/plans/task-schedule';
import { buildPlanTaskScheduleMonthGroups } from './build-plan-task-schedule-month-groups';

function task(
  overrides: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): TaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    task_type: 'general',
    category: 'general',
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: overrides.field_cultivation_id ?? 10,
    completed: false,
    work_records: [],
    details: {
      stage: { name: 'Stage', order: 1 },
      gdd: { trigger: '100', tolerance: '10' },
      priority: 1,
      weather_dependency: 'low',
      time_per_sqm: '0',
      amount: '',
      amount_unit: '',
      source: 'blueprint',
      master: null,
      history: { rescheduled_at: null, cancelled_at: null }
    },
    badge: { type: 'planned' }
  };
}

function field(overrides: Partial<FieldSchedule> & Pick<FieldSchedule, 'field_cultivation_id'>): FieldSchedule {
  return {
    id: overrides.id ?? 1,
    name: overrides.name ?? 'Field A',
    crop_name: overrides.crop_name ?? 'Tomato',
    area_sqm: 100,
    field_cultivation_id: overrides.field_cultivation_id,
    crop_id: 20,
    task_options: [],
    schedules: overrides.schedules ?? { general: [], fertilizer: [], unscheduled: [] }
  };
}

const plan: PlanInfo = {
  id: 7,
  name: 'Main Plan',
  status: 'completed',
  planning_start_date: '2026-01-01',
  planning_end_date: '2026-12-31',
  timeline_generated_at: '2026-06-01T00:00:00Z',
  timeline_generated_at_display: '2026-06-01',
  task_schedule_sync_state: 'ready',
  task_schedule_sync_error: null,
  task_schedule_sync_error_crop_id: null
};

describe('buildPlanTaskScheduleMonthGroups', () => {
  const fields = [
    field({
      field_cultivation_id: 10,
      name: 'North',
      schedules: {
        general: [task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10', field_cultivation_id: 10 })],
        fertilizer: [],
        unscheduled: []
      }
    }),
    field({
      id: 2,
      field_cultivation_id: 20,
      name: 'South',
      schedules: {
        general: [task({ item_id: 2, name: 'Harvest', scheduled_date: '2026-07-05', field_cultivation_id: 20 })],
        fertilizer: [],
        unscheduled: []
      }
    })
  ];

  it('groups rows by month in chronological order', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, null, '2026-01-01');

    expect(groups.map((group) => group.monthKey)).toEqual(['2026-06', '2026-07']);
    expect(groups[0]?.rows.map((row) => row.item.name)).toEqual(['Weeding']);
    expect(groups[1]?.rows.map((row) => row.item.name)).toEqual(['Harvest']);
  });

  it('filters rows by field cultivation id', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, 20, '2026-01-01');

    expect(groups).toHaveLength(1);
    expect(groups[0]?.monthKey).toBe('2026-07');
    expect(groups[0]?.rows[0]?.fieldName).toBe('South');
  });

  it('filters rows by fromDate', () => {
    const groups = buildPlanTaskScheduleMonthGroups(plan, fields, null, '2026-06-15');

    expect(groups).toHaveLength(1);
    expect(groups[0]?.monthKey).toBe('2026-07');
    expect(groups[0]?.rows.map((row) => row.item.name)).toEqual(['Harvest']);
  });
});
