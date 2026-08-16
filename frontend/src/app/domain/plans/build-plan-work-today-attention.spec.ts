import { describe, expect, it } from 'vitest';

import { buildPlanWorkTodayAttention } from './build-plan-work-today-attention';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import type { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';

function sampleRow(
  overrides: Partial<WorkDayListRowDto['item']> & { fieldName?: string; cropName?: string } = {}
): WorkDayListRowDto {
  const { fieldName = '北圃場', cropName = 'トマト', ...itemOverrides } = overrides;
  return {
    item: {
      item_id: itemOverrides.item_id ?? 1,
      name: itemOverrides.name ?? '除草',
      task_type: 'field_work',
      category: 'general',
      scheduled_date: itemOverrides.scheduled_date ?? '2026-06-10',
      priority: 1,
      source: 'blueprint',
      weather_dependency: itemOverrides.weather_dependency ?? 'low',
      time_per_sqm: '1',
      amount: '0',
      amount_unit: 'ha',
      status: 'scheduled',
      agricultural_task_id: 1,
      field_cultivation_id: itemOverrides.field_cultivation_id ?? 10,
      completed: itemOverrides.completed ?? false,
      work_records: [],
      details: {
        stage: { name: '生育', order: 1 },
        gdd: { trigger: '100', tolerance: '10' },
        priority: 1,
        weather_dependency: itemOverrides.weather_dependency ?? 'low',
        time_per_sqm: '1',
        amount: '0',
        amount_unit: 'ha',
        source: 'blueprint',
        master: null,
        history: { rescheduled_at: null, cancelled_at: null }
      },
      badge: { type: 'scheduled' }
    },
    fieldName,
    cropName,
    recordedToday: false
  };
}

function sampleSummary(
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
    plan_id: 7,
    unrecorded_count: 0,
    categories: [],
    top_variance_items: [],
    action_required_items: [
      {
        item_id: 1,
        field_cultivation_id: 10,
        category: 'general',
        name: '追肥',
        scheduled_date: '2026-06-01',
        actual_date: '2026-06-10',
        delta_days: 5,
        gdd_trigger: 100,
        gdd_at_actual: 120,
        gdd_delta: 15,
        exceedance_kind: 'both'
      },
      {
        item_id: 2,
        field_cultivation_id: 11,
        category: 'general',
        name: '間引き',
        scheduled_date: '2026-06-02',
        actual_date: '2026-06-08',
        delta_days: 2,
        gdd_trigger: 50,
        gdd_at_actual: 65,
        gdd_delta: 12,
        exceedance_kind: 'gdd'
      },
      {
        item_id: 3,
        field_cultivation_id: 12,
        category: 'fertilizer',
        name: '施肥',
        scheduled_date: '2026-06-03',
        actual_date: '2026-06-10',
        delta_days: 4,
        gdd_trigger: null,
        gdd_at_actual: null,
        gdd_delta: null,
        exceedance_kind: 'days'
      }
    ],
    ...overrides
  };
}

describe('buildPlanWorkTodayAttention', () => {
  it('aggregates frost-risk fields, gdd delay tasks, and threshold-exceeded tasks', () => {
    const attention = buildPlanWorkTodayAttention(sampleSummary(), [
      sampleRow({
        item_id: 20,
        field_cultivation_id: 10,
        fieldName: '北圃場',
        weather_dependency: 'high'
      }),
      sampleRow({
        item_id: 21,
        field_cultivation_id: 11,
        fieldName: '南圃場',
        weather_dependency: 'high'
      }),
      sampleRow({
        item_id: 22,
        field_cultivation_id: 11,
        fieldName: '南圃場',
        weather_dependency: 'medium'
      })
    ]);

    expect(attention.frostRiskCount).toBe(2);
    expect(attention.frostRiskFields.map((field) => field.fieldName)).toEqual([
      '北圃場',
      '南圃場'
    ]);
    expect(attention.gddDelayCount).toBe(2);
    expect(attention.gddDelayTasks.map((task) => task.name)).toEqual(['追肥', '間引き']);
    expect(attention.thresholdExceededCount).toBe(3);
    expect(attention.thresholdExceededTasks.map((task) => task.name)).toEqual([
      '追肥',
      '間引き',
      '施肥'
    ]);
    expect(attention.weatherTriggers).toEqual([]);
    expect(attention.hasAnyAttention).toBe(true);
  });

  it('includes weather triggers from proposals and marks hasAnyAttention', () => {
    const attention = buildPlanWorkTodayAttention(
      sampleSummary({ action_required_items: [] }),
      [sampleRow({ weather_dependency: 'low' })],
      [
        {
          id: 'frost_forecast:100:42',
          trigger_type: 'frost_forecast',
          severity: 'high',
          rationale: {
            forecast_t_min: -2,
            frost_threshold: 0,
            target_cultivation: { field_name: '北圃場', crop_name: 'トマト' }
          },
          moves: []
        }
      ]
    );

    expect(attention.weatherTriggers).toHaveLength(1);
    expect(attention.weatherTriggers[0]?.fieldName).toBe('北圃場');
    expect(attention.weatherTriggers[0]?.cropName).toBe('トマト');
    expect(attention.frostRiskCount).toBe(0);
    expect(attention.hasAnyAttention).toBe(true);
  });

  it('ignores completed rows when detecting frost-risk fields', () => {
    const attention = buildPlanWorkTodayAttention(sampleSummary({ action_required_items: [] }), [
      sampleRow({ weather_dependency: 'high', completed: true })
    ]);

    expect(attention.frostRiskCount).toBe(0);
    expect(attention.weatherTriggers).toEqual([]);
    expect(attention.hasAnyAttention).toBe(false);
  });

  it('returns empty attention when no frost risk and no action items', () => {
    const attention = buildPlanWorkTodayAttention(
      sampleSummary({ action_required_items: [] }),
      [sampleRow({ weather_dependency: 'low' })]
    );

    expect(attention.frostRiskCount).toBe(0);
    expect(attention.gddDelayCount).toBe(0);
    expect(attention.thresholdExceededCount).toBe(0);
    expect(attention.weatherTriggers).toEqual([]);
    expect(attention.hasAnyAttention).toBe(false);
  });
});
