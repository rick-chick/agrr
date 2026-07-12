import { describe, expect, it } from 'vitest';
import type { FieldSchedule, PlanInfo, TaskScheduleItem } from '../../models/plans/task-schedule';
import { flattenPlanTaskSchedule } from './flatten-plan-task-schedule';

function task(overrides: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name'>): TaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    task_type: 'general',
    category: 'general',
    scheduled_date: overrides.scheduled_date ?? null,
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: overrides.status ?? 'planned',
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

describe('flattenPlanTaskSchedule', () => {
  it('flattens scheduled general and fertilizer tasks with field metadata', () => {
    const rows = flattenPlanTaskSchedule(plan, [
      field({
        field_cultivation_id: 10,
        schedules: {
          general: [task({ item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10' })],
          fertilizer: [task({ item_id: 2, name: 'Top dress', scheduled_date: '2026-06-12' })],
          unscheduled: []
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
          fertilizer: [],
          unscheduled: []
        }
      })
    ]);

    expect(rows).toEqual([]);
  });
});
