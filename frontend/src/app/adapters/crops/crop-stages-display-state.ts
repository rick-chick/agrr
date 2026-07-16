import {
  blueprintGenerationReadiness,
  defaultBlueprintReadiness,
  stageRequirementGaps
} from '../../domain/crops/blueprint-generation-readiness';
import type { Crop } from '../../domain/crops/crop';
import { CropStagesViewState } from '../../components/masters/crops/crop-stages.view';

function cropFromStagesViewState(control: CropStagesViewState): Crop {
  return {
    id: 0,
    name: control.formData.name,
    is_reference: false,
    groups: [],
    crop_stages: control.formData.crop_stages
  };
}

export function withCropStagesDisplayState(control: CropStagesViewState): CropStagesViewState {
  if (control.loading || control.error != null) {
    return {
      ...control,
      blueprintReadiness: defaultBlueprintReadiness(),
      stageRequirementGaps: [],
      showBlueprintReadinessChecklist: false,
      showNextStepCta: false
    };
  }

  const stages = control.formData.crop_stages;
  const blueprintReadiness = blueprintGenerationReadiness(
    cropFromStagesViewState(control),
    control.taskScheduleBlueprints
  );
  const gaps = stageRequirementGaps(stages);

  return {
    ...control,
    blueprintReadiness,
    stageRequirementGaps: gaps,
    showBlueprintReadinessChecklist: stages.length > 0 && !blueprintReadiness.stageRequirementsReady,
    showNextStepCta: stages.length > 0 && blueprintReadiness.stageRequirementsReady
  };
}
