import { describe, expect, it } from 'vitest';

import {
  buildPlanWorkTodayAttention,
  hasPlanWorkTodayAttention
} from './build-plan-work-today-attention';

describe('buildPlanWorkTodayAttention', () => {
  it('aggregates frost risk, gdd delay, and threshold exceeded counts', () => {
    const attention = buildPlanWorkTodayAttention(
      { unrecordedCount: 2, thresholdExceededCount: 3, gddDelayCount: 1 },
      2
    );

    expect(attention).toEqual({
      frostRiskCount: 2,
      gddDelayCount: 1,
      thresholdExceededCount: 3
    });
    expect(hasPlanWorkTodayAttention(attention)).toBe(true);
  });

  it('returns null when all counts are zero', () => {
    const attention = buildPlanWorkTodayAttention(
      { unrecordedCount: 0, thresholdExceededCount: 0, gddDelayCount: 0 },
      0
    );

    expect(attention).toBeNull();
    expect(hasPlanWorkTodayAttention(attention)).toBe(false);
  });

  it('includes frost-only alerts when variance stats are null', () => {
    const attention = buildPlanWorkTodayAttention(null, 1);

    expect(attention).toEqual({
      frostRiskCount: 1,
      gddDelayCount: 0,
      thresholdExceededCount: 0
    });
  });
});
