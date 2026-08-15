import { describe, expect, it } from 'vitest';
import type { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { summarizePlanTaskSchedulePestControl } from './summarize-plan-task-schedule-pest-control';

function pestControlItem(taskType: string, itemId = 1): TaskScheduleItem {
  return {
    item_id: itemId,
    name: taskType,
    task_type: taskType,
    category: 'pest_control',
    scheduled_date: '2026-06-01',
    priority: 1,
    source: 'blueprint',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: 10,
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

function fieldWithPestControl(
  pestControl: TaskScheduleItem[],
  overrides: Partial<FieldSchedule> = {}
): FieldSchedule {
  return {
    id: 1,
    name: 'Field A',
    crop_name: 'Tomato',
    area_sqm: 100,
    field_cultivation_id: 10,
    crop_id: 5,
    schedules: {
      general: [],
      fertilizer: [],
      pest_control: pestControl,
      unscheduled: []
    },
    ...overrides
  };
}

describe('summarizePlanTaskSchedulePestControl', () => {
  it('counts preventive and curative spray tasks across fields', () => {
    const summary = summarizePlanTaskSchedulePestControl([
      fieldWithPestControl([
        pestControlItem('preventive_spray', 1),
        pestControlItem('curative_spray', 2)
      ]),
      fieldWithPestControl([pestControlItem('curative_spray', 3)], {
        id: 2,
        field_cultivation_id: 20
      })
    ]);

    expect(summary).toEqual({ total: 3, preventive: 1, curative: 2 });
  });

  it('returns zero counts when no pest control tasks exist', () => {
    expect(summarizePlanTaskSchedulePestControl([])).toEqual({
      total: 0,
      preventive: 0,
      curative: 0
    });
  });
});
