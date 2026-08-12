import { describe, expect, it } from 'vitest';

import { formatPlanTaskScheduleAverageDeltaDaysLabel, formatPlanTaskScheduleDeltaDaysLabel } from './format-plan-task-schedule-delta-days';

describe('formatPlanTaskScheduleDeltaDaysLabel', () => {
  it('formats each badge kind', () => {
    expect(formatPlanTaskScheduleDeltaDaysLabel({ kind: 'unrecorded', deltaDays: null })).toBe('—');
    expect(formatPlanTaskScheduleDeltaDaysLabel({ kind: 'on_time', deltaDays: 0 })).toBe('±0');
    expect(formatPlanTaskScheduleDeltaDaysLabel({ kind: 'late', deltaDays: 3 })).toBe('+3');
    expect(formatPlanTaskScheduleDeltaDaysLabel({ kind: 'early', deltaDays: -2 })).toBe('-2');
  });
});

describe('formatPlanTaskScheduleAverageDeltaDaysLabel', () => {
  it('rounds to one decimal and preserves sign', () => {
    expect(formatPlanTaskScheduleAverageDeltaDaysLabel(0)).toBe('±0');
    expect(formatPlanTaskScheduleAverageDeltaDaysLabel(1.25)).toBe('+1.3');
    expect(formatPlanTaskScheduleAverageDeltaDaysLabel(-2.44)).toBe('-2.4');
  });
});
