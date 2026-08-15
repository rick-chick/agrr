import { describe, expect, it } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import {
  countWorkDayListFromFields,
  flattenFieldScheduleItems,
  groupWorkDayListRows,
  sumOverdueCounts
} from './work-day-list-summary';

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

describe('flattenFieldScheduleItems', () => {
  it('merges general and fertilizer schedules with field metadata', () => {
    const rows = flattenFieldScheduleItems({
      id: 1,
      name: '第1圃場',
      crop_name: 'トマト',
      area_sqm: 100,
      field_cultivation_id: 10,
      crop_id: 1,
      task_options: [],
      schedules: {
        general: [item({ item_id: 1, scheduled_date: '2026-06-12' })],
        fertilizer: [item({ item_id: 2, scheduled_date: '2026-06-13', name: '追肥' })], pest_control: [],
        unscheduled: []
      }
    });

    expect(rows).toHaveLength(2);
    expect(rows[0]).toMatchObject({
      item: { item_id: 1 },
      fieldName: '第1圃場',
      cropName: 'トマト'
    });
    expect(rows[1].item.name).toBe('追肥');
  });
});

describe('groupWorkDayListRows', () => {
  const today = '2026-06-12';
  const row = (
    overrides: Partial<TaskScheduleItem> & { item_id: number; scheduled_date: string | null }
  ) => ({
    item: item(overrides),
    fieldName: '第1圃場',
    cropName: 'トマト'
  });

  it('attaches overdueDays to overdue rows', () => {
    const grouped = groupWorkDayListRows(
      [row({ item_id: 1, scheduled_date: '2026-06-08' })],
      today,
      false
    );

    expect(grouped.overdue).toHaveLength(1);
    expect(grouped.overdue[0].overdueDays).toBe(4);
    expect(grouped.today).toHaveLength(0);
    expect(grouped.upcoming).toHaveLength(0);
  });

  it('places completed items with today work records in today list', () => {
    const grouped = groupWorkDayListRows(
      [
        row({
          item_id: 1,
          scheduled_date: '2026-06-10',
          completed: true,
          work_records: [{ id: 9, actual_date: today, notes: null }]
        })
      ],
      today,
      false
    );

    expect(grouped.today).toHaveLength(1);
    expect(grouped.today[0].recordedToday).toBe(true);
    expect(grouped.overdue).toHaveLength(0);
  });
});

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
          fertilizer: [], pest_control: [],
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
        schedules: { general: [], fertilizer: [], pest_control: [], unscheduled: [] }
      }
    ];

    expect(countWorkDayListFromFields(fields, today)).toEqual({
      overdueCount: 0,
      todayCount: 0
    });
  });
});

describe('sumOverdueCounts', () => {
  it('sums overdue counts across farms', () => {
    expect(
      sumOverdueCounts([
        { overdueCount: 2 },
        { overdueCount: 0 },
        { overdueCount: 1 }
      ])
    ).toBe(3);
  });

  it('returns zero for empty input', () => {
    expect(sumOverdueCounts([])).toBe(0);
  });
});
