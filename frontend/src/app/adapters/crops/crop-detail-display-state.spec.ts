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
  blueprintReadiness: defaultBlueprintReadiness()
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
});
