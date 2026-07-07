import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

/** UI drafts mirror persisted absolute GDD (cumulative from planting). */
export function blueprintGddDraftsFromBlueprints(
  blueprints: CropTaskScheduleBlueprint[]
): Record<number, number | null> {
  return Object.fromEntries(blueprints.map((blueprint) => [blueprint.id, blueprint.gdd_trigger]));
}
