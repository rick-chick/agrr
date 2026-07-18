import { blueprintGenerationReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { buildBlueprintDetailSummary } from '../../domain/crops/blueprint-detail-summary';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { CropListBlueprintsPanelViewState } from '../../components/masters/crops/crop-list-blueprints-panel.view';

export function withCropListBlueprintsPanelSummaryState(
  control: CropListBlueprintsPanelViewState,
  blueprints: CropTaskScheduleBlueprint[] = []
): CropListBlueprintsPanelViewState {
  const stages = control.crop?.crop_stages ?? [];

  if (control.blueprintsLoading) {
    return {
      ...control,
      blueprintCount: blueprints.length,
      blueprintReadiness: blueprintGenerationReadiness(control.crop, blueprints),
      blueprintSummary: null
    };
  }

  return {
    ...control,
    blueprintCount: blueprints.length,
    blueprintReadiness: blueprintGenerationReadiness(control.crop, blueprints),
    blueprintSummary: buildBlueprintDetailSummary(stages, blueprints)
  };
}
