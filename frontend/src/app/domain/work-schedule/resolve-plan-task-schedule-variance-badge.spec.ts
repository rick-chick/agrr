import { describe, expect, it } from 'vitest';

import { resolvePlanTaskScheduleVarianceBadge } from './resolve-plan-task-schedule-variance-badge';

describe('resolvePlanTaskScheduleVarianceBadge', () => {
  it('returns unrecorded when scheduled but no actual date', () => {
    expect(
      resolvePlanTaskScheduleVarianceBadge({
        scheduled_date: '2026-06-10',
        actualDate: null,
        deltaDays: null,
        status: 'planned'
      })
    ).toEqual({ kind: 'unrecorded', deltaDays: null });
  });

  it('returns on_time when delta is zero', () => {
    expect(
      resolvePlanTaskScheduleVarianceBadge({
        scheduled_date: '2026-06-10',
        actualDate: '2026-06-10',
        deltaDays: 0,
        status: 'planned'
      })
    ).toEqual({ kind: 'on_time', deltaDays: 0 });
  });

  it('returns late when actual is after scheduled', () => {
    expect(
      resolvePlanTaskScheduleVarianceBadge({
        scheduled_date: '2026-06-10',
        actualDate: '2026-06-15',
        deltaDays: 5,
        status: 'planned'
      })
    ).toEqual({ kind: 'late', deltaDays: 5 });
  });

  it('returns early when actual is before scheduled', () => {
    expect(
      resolvePlanTaskScheduleVarianceBadge({
        scheduled_date: '2026-06-10',
        actualDate: '2026-06-07',
        deltaDays: -3,
        status: 'planned'
      })
    ).toEqual({ kind: 'early', deltaDays: -3 });
  });

  it('returns null for skipped items', () => {
    expect(
      resolvePlanTaskScheduleVarianceBadge({
        scheduled_date: '2026-06-10',
        actualDate: null,
        deltaDays: null,
        status: 'skipped'
      })
    ).toBeNull();
  });

  it('returns null when no scheduled date', () => {
    expect(
      resolvePlanTaskScheduleVarianceBadge({
        scheduled_date: null,
        actualDate: null,
        deltaDays: null,
        status: 'planned'
      })
    ).toBeNull();
  });
});
