import { describe, expect, it } from 'vitest';
import { resolvePlanTaskScheduleDisplayStatus } from './resolve-plan-task-schedule-display-status';

describe('resolvePlanTaskScheduleDisplayStatus', () => {
  it('returns completed when work record linkage marks the item completed', () => {
    expect(
      resolvePlanTaskScheduleDisplayStatus({ status: 'planned', completed: true })
    ).toBe('completed');
  });

  it('returns skipped when item is skipped and has no work records', () => {
    expect(
      resolvePlanTaskScheduleDisplayStatus({ status: 'skipped', completed: false })
    ).toBe('skipped');
  });

  it('returns completed when a skipped item has work records', () => {
    expect(
      resolvePlanTaskScheduleDisplayStatus({ status: 'skipped', completed: true })
    ).toBe('completed');
  });

  it('returns planned when item is neither completed nor skipped', () => {
    expect(
      resolvePlanTaskScheduleDisplayStatus({ status: 'planned', completed: false })
    ).toBe('planned');
  });
});
