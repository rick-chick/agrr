import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export function resolveBlueprintGddFromDrop(input: {
  laneBlueprints: ReadonlyArray<CropTaskScheduleBlueprint>;
  draggedBlueprint: CropTaskScheduleBlueprint;
  dropIndex: number;
}): number | null {
  const withoutDragged = input.laneBlueprints.filter(
    (b) => b.id !== input.draggedBlueprint.id
  );
  if (withoutDragged.length === 0) {
    return null;
  }

  const reordered = [...withoutDragged];
  const clampedIndex = Math.max(0, Math.min(input.dropIndex, reordered.length));
  reordered.splice(clampedIndex, 0, input.draggedBlueprint);

  const copySource =
    clampedIndex > 0 ? reordered[clampedIndex - 1] : reordered[clampedIndex + 1];
  if (!copySource) {
    return null;
  }

  const sourceGdd = copySource.gdd_trigger;
  return sourceGdd == null ? null : sourceGdd;
}

export function resolveBlueprintDropUpdate(input: {
  dragged: CropTaskScheduleBlueprint;
  targetStageOrder: number | null;
  laneBlueprints: ReadonlyArray<CropTaskScheduleBlueprint>;
  dropIndex: number;
}): {
  stageOrder?: number | null;
  gddTrigger?: number;
  shouldCommit: boolean;
} {
  const stageChanged = input.dragged.stage_order !== input.targetStageOrder;
  const resolvedGdd = resolveBlueprintGddFromDrop({
    laneBlueprints: input.laneBlueprints,
    draggedBlueprint: input.dragged,
    dropIndex: input.dropIndex
  });

  const gddChanged =
    resolvedGdd != null && resolvedGdd !== input.dragged.gdd_trigger;

  if (!stageChanged && !gddChanged) {
    return { shouldCommit: false };
  }

  const result: {
    stageOrder?: number | null;
    gddTrigger?: number;
    shouldCommit: boolean;
  } = { shouldCommit: true };

  if (stageChanged) {
    result.stageOrder = input.targetStageOrder;
  }
  if (gddChanged && resolvedGdd != null) {
    result.gddTrigger = resolvedGdd;
  }

  return result;
}
