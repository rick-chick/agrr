import { describe, expect, it } from 'vitest';

import { computePlanTaskScheduleMonthAverageDelta } from './compute-plan-task-schedule-month-average-delta';

describe('computePlanTaskScheduleMonthAverageDelta', () => {
  it('returns null when no comparable items exist', () => {
    expect(
      computePlanTaskScheduleMonthAverageDelta([
        { scheduled_date: '2026-06-10', deltaDays: null, status: 'planned' }
      ])
    ).toBeNull();
  });

  it('averages delta days for recorded scheduled items', () => {
    expect(
      computePlanTaskScheduleMonthAverageDelta([
        { scheduled_date: '2026-06-10', deltaDays: 2, status: 'planned' },
        { scheduled_date: '2026-06-12', deltaDays: -2, status: 'planned' }
      ])
    ).toBe(0);
  });

  it('ignores skipped and unscheduled items', () => {
    expect(
      computePlanTaskScheduleMonthAverageDelta([
        { scheduled_date: '2026-06-10', deltaDays: 4, status: 'planned' },
        { scheduled_date: '2026-06-11', deltaDays: 10, status: 'skipped' },
        { scheduled_date: null, deltaDays: 99, status: 'planned' }
      ])
    ).toBe(4);
  });
});
