import { blueprintRegenerateErrorShowsRetry } from '../../core/crop-blueprint-regenerate-error-i18n';
import { blueprintGenerationReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';
import { groupBlueprintsByStage } from '../../domain/crops/blueprint-stage-grouping';
import {
  blueprintGddErrorsForDrafts,
  blueprintLaneOutOfRangeCounts as computeBlueprintLaneOutOfRangeCounts
} from '../../domain/crops/blueprint-gdd-display';
import type { BlueprintGddValidationError } from '../../domain/crops/blueprint-gdd-validation';
import { blueprintGddValidationError } from '../../domain/crops/blueprint-gdd-validation';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { CropTaskScheduleBlueprintsViewState } from '../../components/masters/crops/crop-task-schedule-blueprints.view';
import { cropStageNameForOrder } from '../../domain/crops/crop-stage-name';
import { cumulativeGddTimelineSegments } from '../../domain/crops/cumulative-gdd-timeline';
import { stageCumulativeGddRange } from '../../domain/crops/stage-cumulative-gdd';

function unassociatedAgriculturalTasks(
  blueprints: CropTaskScheduleBlueprint[],
  agriculturalTasks: AgriculturalTask[]
): AgriculturalTask[] {
  const usedIds = new Set(
    blueprints
      .map((b) => b.agricultural_task_id)
      .filter((id): id is number => id != null)
  );
  return agriculturalTasks.filter((task) => !usedIds.has(task.id));
}

function enrichBlueprintsWithAgriculturalTasks(
  blueprints: CropTaskScheduleBlueprint[],
  agriculturalTasks: AgriculturalTask[]
): CropTaskScheduleBlueprint[] {
  if (!agriculturalTasks.length) {
    return blueprints;
  }
  const tasksById = new Map(agriculturalTasks.map((task) => [task.id, task]));
  return blueprints.map((blueprint) => {
    if (blueprint.name?.trim() || blueprint.agricultural_task?.name?.trim()) {
      return blueprint;
    }
    const taskId = blueprint.agricultural_task_id;
    if (taskId == null) {
      return blueprint;
    }
    const task = tasksById.get(taskId);
    if (!task) {
      return blueprint;
    }
    return {
      ...blueprint,
      name: blueprint.name ?? task.name,
      agricultural_task: blueprint.agricultural_task ?? {
        id: task.id,
        name: task.name,
        description: task.description ?? null,
        is_reference: task.is_reference
      }
    };
  });
}

function blueprintStageNameForCreate(control: CropTaskScheduleBlueprintsViewState): string | null {
  return cropStageNameForOrder(control.crop, control.selectedBlueprintStageOrder);
}

function visibleBlueprintGddErrors(
  errors: Record<number, BlueprintGddValidationError | null>,
  touched: Record<number, boolean>
): Record<number, BlueprintGddValidationError | null> {
  const visible: Record<number, BlueprintGddValidationError | null> = {};
  for (const [id, error] of Object.entries(errors)) {
    const blueprintId = Number(id);
    if (touched[blueprintId] && error) {
      visible[blueprintId] = error;
    }
  }
  return visible;
}

function canCreateBlueprint(control: CropTaskScheduleBlueprintsViewState): boolean {
  if (control.blueprintCreating || control.selectedBlueprintAgriculturalTaskId == null) {
    return false;
  }
  const stages = control.crop?.crop_stages ?? [];
  if (stages.length > 0 && control.selectedBlueprintStageOrder == null) {
    return false;
  }
  if (!control.blueprintCreateFormAttempted) {
    return true;
  }
  const createError = blueprintGddValidationError(
    stages,
    control.selectedBlueprintStageOrder,
    control.blueprintCreateGddTrigger
  );
  return (
    createError !== 'out_of_range' &&
    createError !== 'stage_gdd_missing' &&
    createError !== 'missing_stage'
  );
}

export function withCropBlueprintDisplayState(
  control: CropTaskScheduleBlueprintsViewState
): CropTaskScheduleBlueprintsViewState {
  const blueprints = enrichBlueprintsWithAgriculturalTasks(
    control.blueprints,
    control.agriculturalTasks
  );
  const blueprintReadiness = blueprintGenerationReadiness(control.crop, blueprints);
  const blueprintRegenerateError = control.blueprintRegenerateError;
  const stages = control.crop?.crop_stages ?? [];
  const blueprintStageLanes = groupBlueprintsByStage(
    stages,
    blueprints,
    control.blueprintGddDrafts
  );
  const allBlueprintGddErrors = blueprintGddErrorsForDrafts(
    stages,
    blueprints,
    control.blueprintGddDrafts
  );
  const blueprintGddErrors = visibleBlueprintGddErrors(
    allBlueprintGddErrors,
    control.blueprintGddTouched
  );
  const blueprintLaneOutOfRangeCounts = computeBlueprintLaneOutOfRangeCounts(
    stages,
    blueprintStageLanes,
    control.blueprintGddDrafts
  );
  const blueprintCreateGddError: BlueprintGddValidationError | null =
    control.blueprintCreateFormAttempted
      ? blueprintGddValidationError(
          stages,
          control.selectedBlueprintStageOrder,
          control.blueprintCreateGddTrigger
        )
      : null;
  const selectedStageGddRange =
    control.selectedBlueprintStageOrder == null
      ? null
      : stageCumulativeGddRange(stages, control.selectedBlueprintStageOrder);
  const timelineSegments = cumulativeGddTimelineSegments(stages);

  return {
    ...control,
    blueprints,
    blueprintStageLanes,
    cumulativeGddTimelineSegments: timelineSegments,
    blueprintGddErrors,
    blueprintLaneOutOfRangeCounts,
    blueprintCreateGddError,
    selectedStageGddRange,
    unassociatedAgriculturalTasks: unassociatedAgriculturalTasks(
      blueprints,
      control.agriculturalTasks
    ),
    blueprintReadiness,
    canRegenerateBlueprints: blueprintReadiness.ready && !control.blueprintsRegenerating,
    canCreateBlueprint: canCreateBlueprint(control),
    blueprintStageNameForCreate: blueprintStageNameForCreate(control),
    showBlueprintReadinessChecklist:
      !control.blueprintsLoading &&
      !blueprintReadiness.ready &&
      !control.blueprintsRegenerating,
    blueprintSectionDescriptionKey:
      control.fromPlanId != null
        ? null
        : blueprints.length
          ? 'crops.show.task_schedule_blueprints_lead'
          : null,
    showBlueprintEmptyState: !blueprints.length && !blueprintRegenerateError,
    showBlueprintRegenerateRetry:
      blueprintReadiness.ready &&
      blueprintRegenerateError != null &&
      blueprintRegenerateErrorShowsRetry(blueprintRegenerateError)
  };
}
