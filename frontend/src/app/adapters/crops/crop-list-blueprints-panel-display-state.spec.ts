import { describe, expect, it } from 'vitest';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { withCropListBlueprintsPanelSummaryState } from './crop-list-blueprints-panel-display-state';
import type { CropListBlueprintsPanelViewState } from '../../components/masters/crops/crop-list-blueprints-panel.view';

const baseControl: CropListBlueprintsPanelViewState = {
  loading: false,
  error: null,
  crop: {
    id: 3,
    name: 'Tomato',
    is_reference: false,
    groups: [],
    crop_stages: [
      {
        id: 1,
        crop_id: 3,
        name: 'Vegetative',
        order: 1,
        temperature_requirement: {
          id: 1,
          crop_stage_id: 1,
          base_temperature: 10,
          optimal_min: 15,
          optimal_max: 25
        },
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 500 }
      }
    ]
  },
  blueprintsLoading: false,
  blueprintCount: 0,
  blueprintReadiness: defaultBlueprintReadiness(),
  blueprintSummary: null
};

describe('withCropListBlueprintsPanelSummaryState', () => {
  it('computes blueprint count and readiness from blueprints', () => {
    const next = withCropListBlueprintsPanelSummaryState(baseControl, [
      {
        id: 20,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 100,
        gdd_tolerance: null,
        task_type: 'field_work',
        source: 'agrr',
        priority: 1,
        amount: null,
        amount_unit: null,
        description: null,
        weather_dependency: null,
        time_per_sqm: null
      }
    ]);

    expect(next.blueprintCount).toBe(1);
    expect(next.blueprintReadiness.blueprintsReady).toBe(true);
    expect(next.blueprintReadiness.stageRequirementsReady).toBe(true);
    expect(next.blueprintReadiness.ready).toBe(true);
    expect(next.blueprintSummary?.lanes).toHaveLength(1);
    expect(next.blueprintSummary?.attentionCount).toBe(0);
  });

  it('defers blueprint summary while blueprints are loading', () => {
    const next = withCropListBlueprintsPanelSummaryState(
      { ...baseControl, blueprintsLoading: true },
      [
        {
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 100,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'agrr',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        }
      ]
    );

    expect(next.blueprintCount).toBe(1);
    expect(next.blueprintReadiness.blueprintsReady).toBe(true);
    expect(next.blueprintSummary).toBeNull();
  });

  it('surfaces attention count when blueprint GDD is out of range', () => {
    const next = withCropListBlueprintsPanelSummaryState(baseControl, [
      {
        id: 20,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 900,
        gdd_tolerance: null,
        task_type: 'field_work',
        source: 'agrr',
        priority: 1,
        amount: null,
        amount_unit: null,
        description: null,
        weather_dependency: null,
        time_per_sqm: null,
        name: 'Weeding'
      }
    ]);

    expect(next.blueprintSummary?.attentionCount).toBeGreaterThan(0);
    expect(next.blueprintSummary?.lanes[0].items[0].taskName).toBe('Weeding');
  });
});
