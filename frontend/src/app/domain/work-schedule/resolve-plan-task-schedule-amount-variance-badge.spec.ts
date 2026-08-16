import { describe, expect, it } from 'vitest';
import { AMOUNT_VARIANCE_THRESHOLD } from '../plans/plan-variance-thresholds';
import { resolvePlanTaskScheduleAmountVarianceBadge } from './resolve-plan-task-schedule-amount-variance-badge';

describe('resolvePlanTaskScheduleAmountVarianceBadge', () => {
  it('returns null when amount delta is below threshold', () => {
    expect(
      resolvePlanTaskScheduleAmountVarianceBadge({
        status: 'completed',
        amountDelta: AMOUNT_VARIANCE_THRESHOLD - 0.01
      })
    ).toBeNull();
  });

  it('returns over badge when amount delta exceeds threshold positively', () => {
    expect(
      resolvePlanTaskScheduleAmountVarianceBadge({
        status: 'completed',
        amountDelta: 1.2
      })
    ).toEqual({ kind: 'over', amountDelta: 1.2 });
  });

  it('returns under badge when amount delta exceeds threshold negatively', () => {
    expect(
      resolvePlanTaskScheduleAmountVarianceBadge({
        status: 'completed',
        amountDelta: -0.8
      })
    ).toEqual({ kind: 'under', amountDelta: -0.8 });
  });

  it('returns null for skipped items', () => {
    expect(
      resolvePlanTaskScheduleAmountVarianceBadge({
        status: 'skipped',
        amountDelta: 2
      })
    ).toBeNull();
  });
});
