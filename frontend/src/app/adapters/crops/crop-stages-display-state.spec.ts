import { describe, expect, it } from 'vitest';
import { withCropStagesDisplayState } from './crop-stages-display-state';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import type { CropStagesViewState } from '../../components/masters/crops/crop-stages.view';

const baseControl = (
  overrides: Partial<CropStagesViewState> = {}
): CropStagesViewState => ({
  loading: false,
  error: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  pendingReorderCropStagesSnapshot: null,
  pendingResyncPanelDraft: false,
  taskScheduleBlueprints: [],
  formData: {
    name: 'Tomato',
    crop_stages: []
  },
  blueprintReadiness: defaultBlueprintReadiness(),
  stageRequirementGaps: [],
  showBlueprintReadinessChecklist: false,
  showNextStepCta: false,
  ...overrides
});

describe('withCropStagesDisplayState', () => {
  it('hides readiness UI while loading or in error', () => {
    expect(withCropStagesDisplayState(baseControl({ loading: true })).showBlueprintReadinessChecklist).toBe(
      false
    );
    expect(
      withCropStagesDisplayState(baseControl({ error: 'failed' })).showBlueprintReadinessChecklist
    ).toBe(false);
  });

  it('shows checklist when stages exist but requirements are incomplete', () => {
    const next = withCropStagesDisplayState(
      baseControl({
        formData: {
          name: 'Tomato',
          crop_stages: [{ id: 1, name: 'Germination', order: 1 } as CropStagesViewState['formData']['crop_stages'][0]]
        }
      })
    );

    expect(next.showBlueprintReadinessChecklist).toBe(true);
    expect(next.showNextStepCta).toBe(false);
    expect(next.stageRequirementGaps).toHaveLength(1);
  });

  it('shows next-step CTA when stage requirements are complete', () => {
    const next = withCropStagesDisplayState(
      baseControl({
        formData: {
          name: 'Tomato',
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Germination',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10
              },
              thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 100 }
            }
          ]
        }
      })
    );

    expect(next.showBlueprintReadinessChecklist).toBe(false);
    expect(next.showNextStepCta).toBe(true);
    expect(next.blueprintReadiness.stageRequirementsReady).toBe(true);
  });
});
