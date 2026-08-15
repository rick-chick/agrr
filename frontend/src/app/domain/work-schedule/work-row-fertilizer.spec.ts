import { describe, expect, it } from 'vitest';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import {
  filterWorkDayListBySegment,
  formatWorkRowAmountDiffLabel,
  isFertilizerWorkRow,
  isPestControlWorkRow,
  resolveFertilizerTaskKind,
  resolvePestControlTaskKind,
  resolveWorkRowAmountDiff
} from './work-row-fertilizer';

function row(overrides: Partial<TaskScheduleItem> = {}): WorkDayListRowDto {
  return {
    item: {
      item_id: 1,
      name: '追肥',
      task_type: 'topdress_fertilization',
      category: 'fertilizer',
      scheduled_date: '2026-06-17',
      stage_name: '',
      stage_order: 0,
      gdd_trigger: '',
      gdd_tolerance: '',
      priority: 1,
      source: 'agrr',
      weather_dependency: 'none',
      time_per_sqm: '',
      amount: '10',
      amount_unit: 'kg',
      status: 'pending',
      agricultural_task_id: 1,
      field_cultivation_id: 1,
      completed: false,
      work_records: [],
      details: {},
      badge: { label: '', tone: 'default' },
      ...overrides
    } as TaskScheduleItem,
    fieldName: 'A区画',
    cropName: 'トマト',
    recordedToday: false
  };
}

describe('work-row-fertilizer', () => {
  it('identifies fertilizer bucket rows by category', () => {
    expect(isFertilizerWorkRow(row())).toBe(true);
    expect(isFertilizerWorkRow(row({ category: 'general' }))).toBe(false);
  });

  it('resolves basal and topdress kinds from task_type', () => {
    expect(resolveFertilizerTaskKind(row({ task_type: 'basal_fertilization' }).item)).toBe('basal');
    expect(resolveFertilizerTaskKind(row({ task_type: 'topdress_fertilization' }).item)).toBe(
      'topdress'
    );
    expect(resolveFertilizerTaskKind(row({ task_type: 'field_work' }).item)).toBeNull();
  });

  it('filters rows by fertilizer segment', () => {
    const general = row({ item_id: 1, category: 'general', name: '除草' });
    const fertilizer = row({ item_id: 2, category: 'fertilizer', name: '追肥' });
    const rows = [general, fertilizer];

    expect(filterWorkDayListBySegment(rows, 'all')).toEqual(rows);
    expect(filterWorkDayListBySegment(rows, 'fertilizer')).toEqual([fertilizer]);
  });

  it('computes amount diff from planned item amount and latest record', () => {
    const diff = resolveWorkRowAmountDiff(row(), '12', 'kg');
    expect(diff).toEqual({ planned: 10, actual: 12, diff: 2, unit: 'kg' });
  });

  it('returns null diff when neither planned nor actual amount exists', () => {
    expect(
      resolveWorkRowAmountDiff(row({ amount: '', amount_unit: '' }), null, null)
    ).toBeNull();
  });

  it('formats signed amount diff label', () => {
    const diff = resolveWorkRowAmountDiff(row(), '8', 'kg');
    expect(formatWorkRowAmountDiffLabel(diff!)).toBe('-2 kg');
  });

  it('identifies pest_control bucket rows by category', () => {
    expect(isPestControlWorkRow(row({ category: 'pest_control' }))).toBe(true);
    expect(isPestControlWorkRow(row({ category: 'general' }))).toBe(false);
  });

  it('resolves preventive and curative kinds from task_type', () => {
    expect(resolvePestControlTaskKind(row({ task_type: 'preventive_spray' }).item)).toBe(
      'preventive'
    );
    expect(resolvePestControlTaskKind(row({ task_type: 'curative_spray' }).item)).toBe('curative');
    expect(resolvePestControlTaskKind(row({ task_type: 'field_work' }).item)).toBeNull();
  });

  it('filters rows by pest_control segment', () => {
    const general = row({ item_id: 1, category: 'general', name: '除草' });
    const preventive = row({
      item_id: 2,
      category: 'pest_control',
      task_type: 'preventive_spray',
      name: '予防散布'
    });
    const rows = [general, preventive];

    expect(filterWorkDayListBySegment(rows, 'all')).toEqual(rows);
    expect(filterWorkDayListBySegment(rows, 'pest_control')).toEqual([preventive]);
  });
});
