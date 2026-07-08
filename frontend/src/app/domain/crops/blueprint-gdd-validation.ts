import { stageCumulativeGddRange } from './stage-cumulative-gdd';
import type { CropStage } from './crop';

export type BlueprintGddValidationError =
  | 'missing_stage'
  | 'out_of_range'
  | 'stage_gdd_missing'
  | 'gdd_required';

export function blueprintGddValidationError(
  stages: CropStage[],
  stageOrder: number | null,
  gddTrigger: number | null
): BlueprintGddValidationError | null {
  if (stages.length === 0) {
    return null;
  }
  if (stageOrder == null) {
    return 'missing_stage';
  }

  const range = stageCumulativeGddRange(stages, stageOrder);
  if (range.gddRangeMissing) {
    return gddTrigger == null ? null : 'stage_gdd_missing';
  }

  if (gddTrigger == null || Number.isNaN(gddTrigger)) {
    return null;
  }

  const start = range.cumulativeGddStart!;
  const end = range.cumulativeGddEnd!;
  if (gddTrigger < start || gddTrigger > end) {
    return 'out_of_range';
  }

  return null;
}
