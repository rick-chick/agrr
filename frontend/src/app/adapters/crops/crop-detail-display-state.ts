import { blueprintGenerationReadiness } from '../../domain/crops/blueprint-generation-readiness';
import {
  buildBlueprintDetailSummary,
  emptyBlueprintDetailSummary
} from '../../domain/crops/blueprint-detail-summary';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';

export function withCropDetailSummaryState(
  control: CropDetailViewState,
  blueprints: CropTaskScheduleBlueprint[] = []
): CropDetailViewState {
  const blueprintSummary = control.blueprintsLoading
    ? null
    : buildBlueprintDetailSummary(control.crop?.crop_stages ?? [], blueprints);

  return {
    ...control,
    blueprintCount: blueprints.length,
    blueprintReadiness: blueprintGenerationReadiness(control.crop, blueprints),
    blueprintSummary
  };
}

export { defaultBlueprintReadiness, emptyBlueprintDetailSummary };
