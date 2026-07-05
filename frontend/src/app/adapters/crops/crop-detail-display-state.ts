import { blueprintRegenerateErrorShowsRetry } from '../../core/crop-blueprint-regenerate-error-i18n';
import { blueprintGenerationReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';
import { groupBlueprintsByStage } from '../../domain/crops/blueprint-stage-grouping';
import { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';
import { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';
import { cropStageNameForOrder } from '../../domain/crops/crop-stage-name';

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

function blueprintStageNameForCreate(control: CropDetailViewState): string | null {
  return cropStageNameForOrder(control.crop, control.selectedBlueprintStageOrder);
}

export function withCropDetailDisplayState(control: CropDetailViewState): CropDetailViewState {
  const blueprints = enrichBlueprintsWithAgriculturalTasks(
    control.blueprints,
    control.agriculturalTasks
  );
  const blueprintReadiness = blueprintGenerationReadiness(control.crop, blueprints);
  const blueprintRegenerateError = control.blueprintRegenerateError;

  return {
    ...control,
    blueprints,
    blueprintStageLanes: groupBlueprintsByStage(control.crop?.crop_stages ?? [], blueprints),
    unassociatedAgriculturalTasks: unassociatedAgriculturalTasks(
      blueprints,
      control.agriculturalTasks
    ),
    blueprintReadiness,
    canRegenerateBlueprints: blueprintReadiness.ready && !control.blueprintsRegenerating,
    canCreateBlueprint:
      !control.blueprintCreating && control.selectedBlueprintAgriculturalTaskId != null,
    blueprintStageNameForCreate: blueprintStageNameForCreate(control),
    showBlueprintReadinessChecklist:
      !control.blueprintsLoading &&
      !blueprintReadiness.ready &&
      !control.blueprintsRegenerating,
    blueprintSectionDescriptionKey: blueprints.length
      ? 'crops.show.task_schedule_blueprints_description_html'
      : 'crops.show.task_schedule_blueprints_description_empty_html',
    showBlueprintEmptyState: !blueprints.length && !blueprintRegenerateError,
    showBlueprintRegenerateRetry:
      blueprintReadiness.ready &&
      blueprintRegenerateError != null &&
      blueprintRegenerateErrorShowsRetry(blueprintRegenerateError)
  };
}
