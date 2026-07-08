import { describe, expect, it } from 'vitest';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { withCropDetailSummaryState } from './crop-detail-display-state';
import type { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';

const baseControl: CropDetailViewState = {
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
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  blueprintsLoading: false,
  blueprintCount: 0,
  blueprintReadiness: defaultBlueprintReadiness(),
  blueprintSummary: null,
  stageBoardColumns: [],
  cumulativeGddTimelineSegments: []
};

describe('withCropDetailSummaryState', () => {
  it('computes blueprint count and readiness from blueprints', () => {
    const next = withCropDetailSummaryState(baseControl, [
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
    expect(next.blueprintSummary?.lanes[0].items[0].taskName).toBeNull();
    expect(next.blueprintSummary?.attentionCount).toBe(0);
  });

  it('builds blueprint summary lanes when crop and blueprints are present', () => {
    const next = withCropDetailSummaryState(
      baseControl,
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
          time_per_sqm: null,
          name: 'Weeding'
        }
      ]
    );

    expect(next.blueprintSummary?.lanes[0].items[0].taskName).toBe('Weeding');
    expect(next.blueprintSummary?.attentionCount).toBe(0);
  });

  it('passes gddGroups from buildBlueprintDetailSummary through view state', () => {
    const next = withCropDetailSummaryState(
      baseControl,
      [
        {
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 200,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'agrr',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null,
          name: 'Planting'
        },
        {
          id: 21,
          crop_id: 3,
          agricultural_task_id: 6,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 200,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'agrr',
          priority: 2,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null,
          name: 'Tilling'
        }
      ]
    );

    expect(next.blueprintSummary?.lanes[0].gddGroups).toEqual([
      {
        gddTrigger: 200,
        items: [
          expect.objectContaining({ taskName: 'Planting' }),
          expect.objectContaining({ taskName: 'Tilling' })
        ]
      }
    ]);
  });

  it('keeps blueprintSummary null while blueprints are loading', () => {
    const next = withCropDetailSummaryState(
      { ...baseControl, blueprintsLoading: true },
      [{ id: 1, crop_id: 3, agricultural_task_id: 5, source_agricultural_task_id: null, stage_order: 1, stage_name: 'S', gdd_trigger: 10, gdd_tolerance: null, task_type: 'field_work', source: 'manual', priority: 1, amount: null, amount_unit: null, description: null, weather_dependency: null, time_per_sqm: null }]
    );

    expect(next.blueprintSummary).toBeNull();
  });

  it('reports attention count for unset timing', () => {
    const next = withCropDetailSummaryState(baseControl, [
      {
        id: 20,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: null,
        gdd_tolerance: null,
        task_type: 'field_work',
        source: 'agrr',
        priority: 1,
        amount: null,
        amount_unit: null,
        description: null,
        weather_dependency: null,
        time_per_sqm: null,
        name: 'Irrigation'
      }
    ]);

    expect(next.blueprintSummary?.unsetTimingCount).toBe(1);
    expect(next.blueprintSummary?.attentionCount).toBe(1);
  });

  it('reports setup required when stages lack requirements', () => {
    const next = withCropDetailSummaryState(
      {
        ...baseControl,
        crop: { ...baseControl.crop!, crop_stages: [{ id: 1, crop_id: 3, name: 'S', order: 1 }] }
      },
      []
    );

    expect(next.blueprintCount).toBe(0);
    expect(next.blueprintReadiness.ready).toBe(false);
  });

  it('builds stage board columns and cumulative timeline segments when loaded', () => {
    const next = withCropDetailSummaryState(baseControl, [
      {
        id: 20,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 0,
        gdd_tolerance: null,
        task_type: 'field_work',
        source: 'agrr',
        priority: 1,
        amount: null,
        amount_unit: null,
        description: null,
        weather_dependency: null,
        time_per_sqm: null,
        name: 'Sowing'
      }
    ]);

    expect(next.stageBoardColumns).toHaveLength(1);
    expect(next.stageBoardColumns[0]).toMatchObject({
      stageOrder: 1,
      requiredGdd: 500,
      optimalMin: 15,
      optimalMax: 25,
      cumulativeGddStart: 0,
      cumulativeGddEnd: 500
    });
    expect(next.stageBoardColumns[0].gddGroups[0].items[0].taskName).toBe('Sowing');
    expect(next.cumulativeGddTimelineSegments).toEqual([
      {
        stageOrder: 1,
        stageName: 'Vegetative',
        cumulativeGddStart: 0,
        cumulativeGddEnd: 500
      }
    ]);
  });

  it('keeps stage board empty while blueprints are loading', () => {
    const next = withCropDetailSummaryState(
      { ...baseControl, blueprintsLoading: true },
      []
    );

    expect(next.stageBoardColumns).toEqual([]);
    expect(next.cumulativeGddTimelineSegments).toEqual([]);
  });
});
