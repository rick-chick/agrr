import { blueprintGenerationReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { buildBlueprintDetailSummary } from '../../domain/crops/blueprint-detail-summary';
import { buildCropDetailStageBoard } from '../../domain/crops/crop-detail-stage-board';
import { cumulativeGddTimelineSegments } from '../../domain/crops/cumulative-gdd-timeline';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';

export function withCropDetailSummaryState(
  control: CropDetailViewState,
  blueprints: CropTaskScheduleBlueprint[] = []
): CropDetailViewState {
  const stages = control.crop?.crop_stages ?? [];

  if (control.blueprintsLoading) {
    return {
      ...control,
      blueprintCount: blueprints.length,
      blueprintReadiness: blueprintGenerationReadiness(control.crop, blueprints),
      blueprintSummary: null,
      stageBoardColumns: [],
      cumulativeGddTimelineSegments: []
    };
  }

  const blueprintSummary = buildBlueprintDetailSummary(stages, blueprints);
  const stageBoard = buildCropDetailStageBoard(stages, blueprints, blueprintSummary);

  return {
    ...control,
    blueprintCount: blueprints.length,
    blueprintReadiness: blueprintGenerationReadiness(control.crop, blueprints),
    blueprintSummary,
    stageBoardColumns: stageBoard.columns,
    cumulativeGddTimelineSegments: cumulativeGddTimelineSegments(stages)
  };
}
