import { describe, expect, it } from 'vitest';
import type { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { summarizePlanTaskScheduleFertilizer } from './summarize-plan-task-schedule-fertilizer';

function fertilizerItem(taskType: string, itemId = 1): TaskScheduleItem {
  return {
    item_id: itemId,
    name: taskType,
    task_type: taskType,
    category: 'fertilizer',
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

function fieldWithFertilizer(
  fertilizer: TaskScheduleItem[],
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
      fertilizer,
      unscheduled: []
    },
    ...overrides
  };
}

describe('summarizePlanTaskScheduleFertilizer', () => {
  it('counts basal and topdress fertilizer tasks across fields', () => {
    const summary = summarizePlanTaskScheduleFertilizer([
      fieldWithFertilizer([
        fertilizerItem('basal_fertilization', 1),
        fertilizerItem('topdress_fertilization', 2)
      ]),
      fieldWithFertilizer([fertilizerItem('topdress_fertilization', 3)], {
        id: 2,
        field_cultivation_id: 20
      })
    ]);

    expect(summary).toEqual({ total: 3, basal: 1, topdress: 2 });
  });

  it('returns zero counts when no fertilizer tasks exist', () => {
    expect(summarizePlanTaskScheduleFertilizer([])).toEqual({
      total: 0,
      basal: 0,
      topdress: 0
    });
  });
});
