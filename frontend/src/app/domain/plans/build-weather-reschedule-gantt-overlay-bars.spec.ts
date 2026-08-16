import { describe, expect, it } from 'vitest';
import type { CultivationData } from './cultivation-plan-data';
import { buildWeatherRescheduleGanttOverlayBars } from './build-weather-reschedule-gantt-overlay-bars';
import type { WeatherRescheduleProposalPreview } from './weather-reschedule-proposal-preview';

const cultivations: CultivationData[] = [
  {
    id: 42,
    field_id: 1,
    field_name: '北圃場',
    crop_id: 1,
    crop_name: 'トマト',
    area: 10,
    start_date: '2026-04-01',
    completion_date: '2026-07-01',
    cultivation_days: 90,
    estimated_cost: 0,
    revenue: 0,
    profit: 0,
    status: 'active'
  }
];

function previewFixture(
  overrides: Partial<WeatherRescheduleProposalPreview> = {}
): WeatherRescheduleProposalPreview {
  return {
    proposal_id: 'frost_forecast:42:0',
    proposal: {
      id: 'frost_forecast:42:0',
      trigger_type: 'frost_forecast',
      severity: 'high',
      rationale: {},
      moves: []
    },
    moves: [],
    before: { field_schedules: [] },
    after: {
      field_schedules: [
        {
          field_id: '1',
          allocations: [{ allocation_id: 42, start_date: '2026-04-11' }]
        }
      ]
    },
    ...overrides
  };
}

describe('buildWeatherRescheduleGanttOverlayBars', () => {
  it('builds overlay bars from after field_schedules allocations', () => {
    const bars = buildWeatherRescheduleGanttOverlayBars(previewFixture(), cultivations);
    expect(bars).toEqual([
      {
        cultivationId: 42,
        cropName: 'トマト',
        fieldName: '北圃場',
        startDate: '2026-04-11',
        completionDate: '2026-07-10'
      }
    ]);
  });

  it('returns empty when after schedules have no matching cultivations', () => {
    const bars = buildWeatherRescheduleGanttOverlayBars(
      previewFixture({
        after: {
          field_schedules: [
            {
              field_id: '1',
              allocations: [{ allocation_id: 999, start_date: '2026-04-11' }]
            }
          ]
        }
      }),
      cultivations
    );
    expect(bars).toEqual([]);
  });
});
