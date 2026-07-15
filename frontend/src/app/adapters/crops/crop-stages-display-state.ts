import {
  blueprintGenerationReadiness,
  defaultBlueprintReadiness
} from '../../domain/crops/blueprint-generation-readiness';
import type { CropStagesViewState } from '../../components/masters/crops/crop-stages.view';

export function withCropStagesDisplayState(
  control: CropStagesViewState,
  cropId: number
): CropStagesViewState {
  if (control.loading || control.error) {
    return {
      ...control,
      blueprintReadiness: defaultBlueprintReadiness()
    };
  }

  return {
    ...control,
    blueprintReadiness: blueprintGenerationReadiness(
      {
        id: cropId,
        name: control.formData.name,
        is_reference: false,
        groups: [],
        crop_stages:       control.formData.crop_stages
      },
      control.taskScheduleBlueprints
    )
  };
}
