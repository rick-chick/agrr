import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

/** UI drafts mirror persisted absolute cumulative GDD (℃·day from crop start). */
export function blueprintGddDraftsFromBlueprints(
  blueprints: CropTaskScheduleBlueprint[]
): Record<number, number | null> {
  return Object.fromEntries(blueprints.map((blueprint) => [blueprint.id, blueprint.gdd_trigger]));
}
