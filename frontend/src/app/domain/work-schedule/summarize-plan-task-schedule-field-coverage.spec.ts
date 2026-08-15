import { describe, expect, it } from 'vitest';
import {
  countFieldScheduleTasks,
  summarizePlanTaskScheduleFieldCoverage
} from './summarize-plan-task-schedule-field-coverage';

function fieldWithTaskCounts(
  general = 0,
  fertilizer = 0,
  unscheduled = 0
): { schedules: { general: unknown[]; fertilizer: unknown[]; pest_control: unknown[]; unscheduled: unknown[] } } {
  return {
    schedules: {
      general: Array.from({ length: general }, () => ({})),
      fertilizer: Array.from({ length: fertilizer }, () => ({})),
      pest_control: [],
      unscheduled: Array.from({ length: unscheduled }, () => ({}))
    }
  };
}

describe('summarizePlanTaskScheduleFieldCoverage', () => {
  it('returns zero counts when there are no fields', () => {
    expect(summarizePlanTaskScheduleFieldCoverage([])).toEqual({
      totalFieldCount: 0,
      fieldsWithTasksCount: 0,
      fieldsWithoutTasksCount: 0,
      allFieldsLackTasks: false
    });
  });

  it('marks allFieldsLackTasks when every field has zero tasks', () => {
    const fields = [fieldWithTaskCounts(), fieldWithTaskCounts(), fieldWithTaskCounts()];
    expect(summarizePlanTaskScheduleFieldCoverage(fields)).toEqual({
      totalFieldCount: 3,
      fieldsWithTasksCount: 0,
      fieldsWithoutTasksCount: 3,
      allFieldsLackTasks: true
    });
  });

  it('counts mixed fields with and without tasks', () => {
    const fields = [
      fieldWithTaskCounts(2),
      fieldWithTaskCounts(),
      fieldWithTaskCounts(0, 1, 1)
    ];
    expect(summarizePlanTaskScheduleFieldCoverage(fields)).toEqual({
      totalFieldCount: 3,
      fieldsWithTasksCount: 2,
      fieldsWithoutTasksCount: 1,
      allFieldsLackTasks: false
    });
  });
});

describe('countFieldScheduleTasks', () => {
  it('sums general, fertilizer, and unscheduled buckets', () => {
    expect(countFieldScheduleTasks(fieldWithTaskCounts(1, 2, 3))).toBe(6);
  });
});
