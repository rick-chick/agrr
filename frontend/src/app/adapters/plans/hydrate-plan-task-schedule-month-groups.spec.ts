import { describe, expect, it } from 'vitest';
import type { CrossFarmScheduleMonthGroup } from '../../domain/work-schedule/group-cross-farm-schedule-by-month';
import type { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { hydratePlanTaskScheduleMonthGroups } from './hydrate-plan-task-schedule-month-groups';

function task(
  overrides: Partial<TaskScheduleItem> & Pick<TaskScheduleItem, 'item_id' | 'name' | 'scheduled_date'>
): TaskScheduleItem {
  return {
    item_id: overrides.item_id,
    name: overrides.name,
    scheduled_date: overrides.scheduled_date,
    task_type: overrides.task_type ?? 'general',
    category: overrides.category ?? 'general',
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
    work_records: overrides.work_records ?? [],
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
    crop_id: overrides.crop_id ?? 20,
    task_options: [],
    schedules: overrides.schedules ?? { general: [], fertilizer: [], unscheduled: [] }
  };
}

function monthGroup(
  monthKey: string,
  rows: CrossFarmScheduleMonthGroup['rows']
): CrossFarmScheduleMonthGroup {
  return { monthKey, rows };
}

describe('hydratePlanTaskScheduleMonthGroups', () => {
  it('re-attaches full general task rows from field schedules', () => {
    const fullWeeding = task({
      item_id: 1,
      name: 'Weeding',
      scheduled_date: '2026-06-10',
      work_records: [{ id: 99, actual_date: '2026-06-09', notes: 'done' }]
    });
    const fields = [
      field({
        field_cultivation_id: 10,
        schedules: { general: [fullWeeding], fertilizer: [], unscheduled: [] }
      })
    ];
    const groups = [
      monthGroup('2026-06', [
        {
          item: { item_id: 1, name: 'Weeding', scheduled_date: '2026-06-10', status: 'planned' },
          farmId: 1,
          farmName: 'Farm A',
          planId: 7,
          planName: 'Main Plan',
          fieldName: 'Field A',
          fieldCultivationId: 10,
          cropName: 'Tomato'
        }
      ])
    ];

    const hydrated = hydratePlanTaskScheduleMonthGroups(groups, fields);

    expect(hydrated[0]?.rows[0]?.item).toBe(fullWeeding);
    expect(hydrated[0]?.rows[0]?.item.work_records).toHaveLength(1);
  });

  it('indexes fertilizer schedule items when hydrating', () => {
    const fullFertilizer = task({
      item_id: 2,
      name: 'Top dress',
      scheduled_date: '2026-06-12',
      task_type: 'fertilizer',
      category: 'fertilizer'
    });
    const fields = [
      field({
        field_cultivation_id: 10,
        schedules: { general: [], fertilizer: [fullFertilizer], unscheduled: [] }
      })
    ];
    const groups = [
      monthGroup('2026-06', [
        {
          item: { item_id: 2, name: 'Top dress', scheduled_date: '2026-06-12', status: 'planned' },
          farmId: 1,
          farmName: 'Farm A',
          planId: 7,
          planName: 'Main Plan',
          fieldName: 'Field A',
          fieldCultivationId: 10,
          cropName: 'Tomato'
        }
      ])
    ];

    const hydrated = hydratePlanTaskScheduleMonthGroups(groups, fields);

    expect(hydrated[0]?.rows[0]?.item).toBe(fullFertilizer);
    expect(hydrated[0]?.rows[0]?.item.task_type).toBe('fertilizer');
  });

  it('falls back to slim row item when full task row is missing from fields', () => {
    const slimItem = { item_id: 99, name: 'Orphan', scheduled_date: '2026-06-15', status: 'planned' };
    const groups = [
      monthGroup('2026-06', [
        {
          item: slimItem,
          farmId: 1,
          farmName: 'Farm A',
          planId: 7,
          planName: 'Main Plan',
          fieldName: 'Field A',
          fieldCultivationId: 10,
          cropName: 'Tomato'
        }
      ])
    ];

    const hydrated = hydratePlanTaskScheduleMonthGroups(groups, []);

    expect(hydrated[0]?.rows[0]?.item).toEqual(slimItem);
    expect(hydrated[0]?.rows[0]?.item).not.toHaveProperty('details');
  });

  it('preserves month group keys and row metadata', () => {
    const fullTask = task({ item_id: 3, name: 'Harvest', scheduled_date: '2026-07-01' });
    const fields = [
      field({
        field_cultivation_id: 20,
        schedules: { general: [fullTask], fertilizer: [], unscheduled: [] }
      })
    ];
    const row = {
      item: { item_id: 3, name: 'Harvest', scheduled_date: '2026-07-01', status: 'planned' },
      farmId: 2,
      farmName: 'Farm B',
      planId: 8,
      planName: 'Second Plan',
      fieldName: 'South',
      fieldCultivationId: 20,
      cropName: 'Carrot'
    };
    const groups = [monthGroup('2026-07', [row])];

    const hydrated = hydratePlanTaskScheduleMonthGroups(groups, fields);

    expect(hydrated).toEqual([
      {
        monthKey: '2026-07',
        rows: [{ ...row, item: fullTask }]
      }
    ]);
  });
});
