import { blueprintGenerationReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';

export function withCropDetailSummaryState(
  control: CropDetailViewState,
  blueprints: CropTaskScheduleBlueprint[] = []
): CropDetailViewState {
  return {
    ...control,
    blueprintCount: blueprints.length,
    blueprintReadiness: blueprintGenerationReadiness(control.crop, blueprints)
  };
}

export { defaultBlueprintReadiness };
