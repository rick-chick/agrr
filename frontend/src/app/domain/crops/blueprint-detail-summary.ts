import type { BlueprintGddValidationError } from './blueprint-gdd-validation';
import { blueprintGddValidationError } from './blueprint-gdd-validation';
import { groupBlueprintsByStage } from './blueprint-stage-grouping';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export type BlueprintDetailSummaryItem = {
  id: number;
  taskName: string | null;
  gddTrigger: number | null;
  gddError: BlueprintGddValidationError | null;
};

export type BlueprintDetailSummaryLane = {
  stageOrder: number | null;
  stageName: string | null;
  cumulativeGddStart: number | null;
  cumulativeGddEnd: number | null;
  gddRangeMissing: boolean;
  outOfRangeCount: number;
  items: BlueprintDetailSummaryItem[];
};

export type BlueprintDetailSummary = {
  lanes: BlueprintDetailSummaryLane[];
  unsetTimingCount: number;
  issueCount: number;
  attentionCount: number;
};

export const emptyBlueprintDetailSummary = (): BlueprintDetailSummary => ({
  lanes: [],
  unsetTimingCount: 0,
  issueCount: 0,
  attentionCount: 0
});

function blueprintTaskName(blueprint: CropTaskScheduleBlueprint): string | null {
  const fromBlueprint = blueprint.name?.trim();
  if (fromBlueprint) {
    return fromBlueprint;
  }
  const fromTask = blueprint.agricultural_task?.name?.trim();
  return fromTask || null;
}

function hasBlueprintWithSameStageAndTask(
  blueprints: CropTaskScheduleBlueprint[],
  blueprint: CropTaskScheduleBlueprint
): boolean {
  if (blueprint.stage_order == null || blueprint.agricultural_task_id == null) {
    return false;
  }
  return blueprints.some(
    (other) =>
      other.id !== blueprint.id &&
      other.stage_order === blueprint.stage_order &&
      other.agricultural_task_id === blueprint.agricultural_task_id
  );
}

function summaryGddError(
  stages: CropStage[],
  blueprint: CropTaskScheduleBlueprint,
  blueprints: CropTaskScheduleBlueprint[]
): BlueprintGddValidationError | null {
  const gddTrigger = blueprint.gdd_trigger;
  if (
    hasBlueprintWithSameStageAndTask(blueprints, blueprint) &&
    (gddTrigger == null || Number.isNaN(gddTrigger))
  ) {
    return 'gdd_required';
  }
  return blueprintGddValidationError(stages, blueprint.stage_order, gddTrigger);
}

function classifyBlueprintAttention(
  stages: CropStage[],
  blueprint: CropTaskScheduleBlueprint,
  blueprints: CropTaskScheduleBlueprint[]
): { unset: boolean; issue: boolean; gddError: BlueprintGddValidationError | null } {
  const gddError = summaryGddError(stages, blueprint, blueprints);
  if (gddError != null) {
    return { unset: false, issue: true, gddError };
  }
  if (blueprint.gdd_trigger == null || Number.isNaN(blueprint.gdd_trigger)) {
    return { unset: true, issue: false, gddError: null };
  }
  return { unset: false, issue: false, gddError: null };
}

function laneOutOfRangeCount(items: BlueprintDetailSummaryItem[]): number {
  return items.filter(
    (item) => item.gddError === 'out_of_range' || item.gddError === 'missing_stage'
  ).length;
}

export function buildBlueprintDetailSummary(
  stages: CropStage[],
  blueprints: CropTaskScheduleBlueprint[]
): BlueprintDetailSummary {
  if (blueprints.length === 0) {
    return emptyBlueprintDetailSummary();
  }

  let unsetTimingCount = 0;
  let issueCount = 0;

  const lanes = groupBlueprintsByStage(stages, blueprints)
    .filter((lane) => lane.blueprints.length > 0)
    .map((lane) => {
      const items = lane.blueprints.map((blueprint) => {
        const attention = classifyBlueprintAttention(stages, blueprint, blueprints);
        if (attention.unset) {
          unsetTimingCount += 1;
        }
        if (attention.issue) {
          issueCount += 1;
        }
        return {
          id: blueprint.id,
          taskName: blueprintTaskName(blueprint),
          gddTrigger: blueprint.gdd_trigger,
          gddError: attention.gddError
        };
      });

      return {
        stageOrder: lane.stageOrder,
        stageName: lane.stageName,
        cumulativeGddStart: lane.cumulativeGddStart,
        cumulativeGddEnd: lane.cumulativeGddEnd,
        gddRangeMissing: lane.gddRangeMissing,
        outOfRangeCount: laneOutOfRangeCount(items),
        items
      };
    });

  return {
    lanes,
    unsetTimingCount,
    issueCount,
    attentionCount: unsetTimingCount + issueCount
  };
}
