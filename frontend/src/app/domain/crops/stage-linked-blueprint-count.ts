import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export function countLinkedTaskScheduleBlueprints(
  stageOrder: number,
  blueprints: CropTaskScheduleBlueprint[]
): number {
  return blueprints.filter((blueprint) => blueprint.stage_order === stageOrder).length;
}
