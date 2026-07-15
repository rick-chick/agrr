import { describe, expect, it } from 'vitest';
import { withCropStagesDisplayState } from './crop-stages-display-state';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import type { CropStagesViewState } from '../../components/masters/crops/crop-stages.view';

const baseControl: CropStagesViewState = {
  loading: false,
  error: null,
  formData: {
    name: 'Tomato',
    crop_stages: []
  },
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingReorderCropStagesSnapshot: null,
  blueprintReadiness: defaultBlueprintReadiness(),
  taskScheduleBlueprints: []
};

describe('withCropStagesDisplayState', () => {
  it('returns default readiness while loading', () => {
    const next = withCropStagesDisplayState(
      { ...baseControl, loading: true },
      1
    );
    expect(next.blueprintReadiness).toEqual(defaultBlueprintReadiness());
  });

  it('marks stage requirements ready when base temperature and GDD are set', () => {
    const next = withCropStagesDisplayState(
      {
        ...baseControl,
        formData: {
          name: 'Tomato',
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10
              },
              thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 }
            }
          ]
        }
      },
      1
    );
    expect(next.blueprintReadiness.stageRequirementsReady).toBe(true);
    expect(next.blueprintReadiness.blueprintsReady).toBe(false);
  });
});
