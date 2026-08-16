import { describe, expect, it } from 'vitest';

import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import {
  isHarvestTaskItem,
  isHarvestWorkRecord,
  isHarvestWorkRow,
  matchesHarvestLabel
} from './work-row-harvest';

function item(overrides: Partial<TaskScheduleItem> = {}): TaskScheduleItem {
  return {
    item_id: 1,
    name: '除草',
    task_type: 'general',
    category: 'general',
    scheduled_date: '2026-07-01',
    priority: 1,
    source: 'plan',
    weather_dependency: 'low',
    time_per_sqm: '0',
    amount: '',
    amount_unit: '',
    status: 'scheduled',
    agricultural_task_id: 1,
    field_cultivation_id: 10,
    completed: false,
    work_records: [],
    details: {
      stage: { name: '生育期', order: 2 },
      gdd: { trigger: '', tolerance: '' },
      priority: 1,
      weather_dependency: 'low',
      time_per_sqm: '0',
      amount: '',
      amount_unit: '',
      source: 'plan',
      master: null,
      history: { rescheduled_at: null, cancelled_at: null }
    },
    badge: { type: 'general' },
    ...overrides
  };
}

function row(overrides: Partial<TaskScheduleItem> = {}): WorkDayListRowDto {
  return {
    item: item(overrides),
    fieldName: 'A',
    cropName: 'トマト',
    recordedToday: false
  };
}

describe('matchesHarvestLabel', () => {
  it('matches Japanese harvest task names', () => {
    expect(matchesHarvestLabel('収穫')).toBe(true);
    expect(matchesHarvestLabel('第一次収穫')).toBe(true);
  });

  it('matches English harvest task names', () => {
    expect(matchesHarvestLabel('Harvest')).toBe(true);
    expect(matchesHarvestLabel('pre-harvest check')).toBe(true);
  });

  it('does not match unrelated task names', () => {
    expect(matchesHarvestLabel('除草')).toBe(false);
    expect(matchesHarvestLabel('Basal fertilization')).toBe(false);
  });
});

describe('isHarvestTaskItem', () => {
  it('returns true for general tasks named harvest', () => {
    expect(isHarvestTaskItem(item({ name: '収穫' }))).toBe(true);
    expect(isHarvestTaskItem(item({ name: 'Harvest' }))).toBe(true);
  });

  it('returns true for general tasks in a harvest stage context', () => {
    expect(
      isHarvestTaskItem(
        item({
          name: '収穫作業',
          details: {
            ...item().details,
            stage: { name: '収穫期', order: 3 }
          }
        })
      )
    ).toBe(true);
  });

  it('returns false for non-general categories', () => {
    expect(isHarvestTaskItem(item({ category: 'fertilizer', name: '収穫' }))).toBe(false);
  });

  it('returns false for unrelated general tasks', () => {
    expect(isHarvestTaskItem(item({ name: '除草' }))).toBe(false);
  });
});

describe('isHarvestWorkRow', () => {
  it('detects harvest rows from task item', () => {
    expect(isHarvestWorkRow(row({ name: '収穫' }))).toBe(true);
    expect(isHarvestWorkRow(row({ name: '間引き' }))).toBe(false);
  });
});

describe('isHarvestWorkRecord', () => {
  it('detects harvest records by name', () => {
    const record: WorkRecord = {
      id: 1,
      cultivation_plan_id: 1,
      field_cultivation_id: 1,
      task_schedule_item_id: 5,
      agricultural_task_id: 1,
      name: '収穫',
      task_type: 'general',
      actual_date: '2026-07-01',
      amount: '12',
      amount_unit: 'kg',
      time_spent_minutes: null,
      notes: null,
      created_at: '2026-07-01T00:00:00Z',
      updated_at: '2026-07-01T00:00:00Z',
      task_schedule_item: { id: 5, name: '収穫', scheduled_date: '2026-07-01' }
    };
    expect(isHarvestWorkRecord(record)).toBe(true);
  });

  it('detects harvest records from linked schedule item name', () => {
    const record: WorkRecord = {
      id: 2,
      cultivation_plan_id: 1,
      field_cultivation_id: 1,
      task_schedule_item_id: 6,
      agricultural_task_id: 1,
      name: '記録',
      task_type: 'general',
      actual_date: '2026-07-02',
      amount: '8',
      amount_unit: 'kg',
      time_spent_minutes: null,
      notes: null,
      created_at: '2026-07-02T00:00:00Z',
      updated_at: '2026-07-02T00:00:00Z',
      task_schedule_item: { id: 6, name: 'Harvest', scheduled_date: '2026-07-02' }
    };
    expect(isHarvestWorkRecord(record)).toBe(true);
  });
});
