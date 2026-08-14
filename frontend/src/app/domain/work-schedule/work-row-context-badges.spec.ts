import { describe, expect, it } from 'vitest';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import {
  resolveWorkRowGddGapState,
  resolveWorkRowGddTrigger,
  resolveWorkRowWeatherDependency,
  shouldShowWorkRowGddGapBadge
} from './work-row-context-badges';

function item(overrides: Partial<TaskScheduleItem> = {}): TaskScheduleItem {
  return {
    item_id: 1,
    name: '追肥',
    task_type: 'field_work',
    category: 'general',
    scheduled_date: '2026-06-17',
    priority: 1,
    source: 'agrr',
    weather_dependency: '',
    time_per_sqm: '',
    amount: '',
    amount_unit: '',
    status: 'pending',
    agricultural_task_id: 1,
    field_cultivation_id: 10,
    completed: false,
    work_records: [],
    details: {
      stage: { name: '', order: 0 },
      gdd: { trigger: '', tolerance: '' },
      priority: 1,
      weather_dependency: '',
      time_per_sqm: '',
      amount: '',
      amount_unit: '',
      source: 'agrr',
      master: null,
      history: { rescheduled_at: null, cancelled_at: null }
    },
    badge: { type: 'field_work' },
    ...overrides
  };
}

describe('work-row-context-badges', () => {
  it('reads gdd trigger from item or details.gdd.trigger', () => {
    expect(resolveWorkRowGddTrigger(item({ gdd_trigger: '120' }))).toBe(120);
    expect(
      resolveWorkRowGddTrigger(
        item({
          gdd_trigger: '',
          details: {
            ...item().details,
            gdd: { trigger: '85.5', tolerance: '' }
          }
        })
      )
    ).toBe(85.5);
    expect(resolveWorkRowGddTrigger(item({ gdd_trigger: '' }))).toBeNull();
  });

  it('returns weather dependency when set and hides empty or none', () => {
    expect(resolveWorkRowWeatherDependency(item({ weather_dependency: 'high' }))).toBe('high');
    expect(
      resolveWorkRowWeatherDependency(
        item({
          weather_dependency: '',
          details: { ...item().details, weather_dependency: 'medium' }
        })
      )
    ).toBe('medium');
    expect(resolveWorkRowWeatherDependency(item({ weather_dependency: 'none' }))).toBeNull();
    expect(resolveWorkRowWeatherDependency(item({ weather_dependency: '' }))).toBeNull();
  });

  it('marks GDD reached when cumulative meets trigger', () => {
    expect(resolveWorkRowGddGapState(100, 120)).toEqual({
      kind: 'reached',
      trigger: 100,
      cumulative: 120
    });
  });

  it('computes shortfall gap when cumulative is below trigger', () => {
    expect(resolveWorkRowGddGapState(120, 95.25)).toEqual({
      kind: 'shortfall',
      trigger: 120,
      cumulative: 95.25,
      gap: 24.8
    });
  });

  it('returns unavailable when trigger or cumulative is missing', () => {
    expect(resolveWorkRowGddGapState(null, 100)).toEqual({ kind: 'unavailable' });
    expect(resolveWorkRowGddGapState(100, null)).toEqual({ kind: 'unavailable' });
  });

  it('hides shortfall gap badge when GDD exceedance badge is shown', () => {
    const shortfall = resolveWorkRowGddGapState(120, 90);
    expect(shouldShowWorkRowGddGapBadge(shortfall, true)).toBe(false);
    expect(shouldShowWorkRowGddGapBadge(shortfall, false)).toBe(true);
    const reached = resolveWorkRowGddGapState(120, 130);
    expect(shouldShowWorkRowGddGapBadge(reached, true)).toBe(true);
  });
});
