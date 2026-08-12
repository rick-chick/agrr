import { describe, expect, it } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { countWorkDayListFromFields } from './work-day-list-summary';

const baseDetails = {
  stage: { name: 'stage', order: 1 },
  gdd: { trigger: '0', tolerance: '0' },
  priority: 1,
  weather_dependency: 'low',
  time_per_sqm: '1',
  amount: '1',
  amount_unit: 'kg',
  source: 'agrr',
  master: null,
  history: { rescheduled_at: null, cancelled_at: null }
};

function item(
  overrides: Partial<TaskScheduleItem> & { item_id: number; scheduled_date: string | null }
): TaskScheduleItem {
  return {
    name: '作業',
    task_type: 'general',
    category: 'general',
    stage_name: 'stage',
    stage_order: 1,
    gdd_trigger: '0',
    gdd_tolerance: '0',
    priority: 1,
    source: 'agrr',
    weather_dependency: 'low',
    time_per_sqm: '1',
    amount: '1',
    amount_unit: 'kg',
    status: 'planned',
    agricultural_task_id: 1,
    field_cultivation_id: 10,
    completed: false,
    work_records: [],
    details: baseDetails,
    badge: { type: 'task', priority_level: 'normal', status: 'planned', category: 'general' },
    ...overrides
  };
}

describe('countWorkDayListFromFields', () => {
  const today = '2026-06-12';

  it('counts overdue and today tasks with skipped excluded by default', () => {
    const fields = [
      {
        id: 1,
        name: '第1圃場',
        crop_name: 'トマト',
        area_sqm: 100,
        field_cultivation_id: 10,
        crop_id: 1,
        task_options: [],
        schedules: {
          general: [
            item({ item_id: 1, scheduled_date: '2026-06-08' }),
            item({ item_id: 2, scheduled_date: today }),
            item({ item_id: 3, scheduled_date: today, status: 'skipped' })
          ],
          fertilizer: [],
          unscheduled: []
        }
      }
    ];

    expect(countWorkDayListFromFields(fields, today)).toEqual({
      overdueCount: 1,
      todayCount: 1
    });
  });

  it('returns zero counts when no scheduled tasks exist', () => {
    const fields = [
      {
        id: 1,
        name: '第1圃場',
        crop_name: 'トマト',
        area_sqm: 100,
        field_cultivation_id: 10,
        crop_id: 1,
        task_options: [],
        schedules: { general: [], fertilizer: [], unscheduled: [] }
      }
    ];

    expect(countWorkDayListFromFields(fields, today)).toEqual({
      overdueCount: 0,
      todayCount: 0
    });
  });
});
