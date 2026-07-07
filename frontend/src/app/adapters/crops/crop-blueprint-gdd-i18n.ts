import type { BlueprintGddValidationError } from '../../domain/crops/blueprint-gdd-validation';
import type { CropStage } from '../../domain/crops/crop';
import type { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import {
  stageCumulativeGddRange,
  type StageCumulativeGddRange
} from '../../domain/crops/stage-cumulative-gdd';

export type CropBlueprintGddInstant = (
  key: string,
  interpolateParams?: Record<string, string | number>
) => string;

export function gddValidationMessage(
  instant: CropBlueprintGddInstant,
  error: BlueprintGddValidationError,
  stages: CropStage[],
  stageOrder: number | null
): string {
  const range =
    stageOrder == null ? null : stageCumulativeGddRange(stages, stageOrder);
  switch (error) {
    case 'missing_stage':
      return instant('crops.show.blueprint_gdd_errors.missing_stage');
    case 'stage_gdd_missing':
      return instant('crops.show.blueprint_gdd_errors.stage_gdd_missing');
    case 'out_of_range':
      return instant('crops.show.blueprint_gdd_errors.out_of_range', {
        start: range?.cumulativeGddStart ?? 0,
        end: range?.cumulativeGddEnd ?? 0
      });
  }
}

export function gddPlaceholderForBlueprint(
  instant: CropBlueprintGddInstant,
  blueprint: CropTaskScheduleBlueprint,
  stages: CropStage[]
): string | null {
  if (blueprint.gdd_trigger != null) {
    return null;
  }
  if (blueprint.stage_order == null || stages.length === 0) {
    return instant('crops.show.gdd_trigger_placeholder');
  }
  const range = stageCumulativeGddRange(stages, blueprint.stage_order);
  if (range.gddRangeMissing || range.cumulativeGddStart == null) {
    return instant('crops.show.gdd_trigger_placeholder');
  }
  return String(range.cumulativeGddStart);
}

export function createGddPlaceholder(
  instant: CropBlueprintGddInstant,
  selectedStageGddRange: StageCumulativeGddRange | null
): string | null {
  if (
    !selectedStageGddRange ||
    selectedStageGddRange.gddRangeMissing ||
    selectedStageGddRange.cumulativeGddStart == null
  ) {
    return instant('crops.show.gdd_trigger_placeholder');
  }
  return String(selectedStageGddRange.cumulativeGddStart);
}
