import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export function countLinkedTaskScheduleBlueprintsForStage(
  stageId: number,
  stages: CropStage[],
  blueprints: CropTaskScheduleBlueprint[]
): number {
  const stage = stages.find((item) => item.id === stageId);
  if (!stage) {
    return 0;
  }
  return blueprints.filter((blueprint) => blueprint.stage_order === stage.order).length;
}
