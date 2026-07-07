import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';
import { buildStageCumulativeGddByOrder } from './stage-cumulative-gdd';

export interface BlueprintStageLane {
  stageOrder: number | null;
  stageName: string | null;
  cumulativeGddStart: number | null;
  cumulativeGddEnd: number | null;
  gddRangeMissing: boolean;
  blueprints: CropTaskScheduleBlueprint[];
}

function gddForSort(
  blueprint: CropTaskScheduleBlueprint,
  drafts: Record<number, number | null>
): number | null {
  if (Object.hasOwn(drafts, blueprint.id)) {
    return drafts[blueprint.id];
  }
  return blueprint.gdd_trigger;
}

function compareBlueprintsByGdd(
  a: CropTaskScheduleBlueprint,
  b: CropTaskScheduleBlueprint,
  drafts: Record<number, number | null>
): number {
  const aGdd = gddForSort(a, drafts);
  const bGdd = gddForSort(b, drafts);
  if (aGdd == null && bGdd == null) {
    return a.id - b.id;
  }
  if (aGdd == null) {
    return 1;
  }
  if (bGdd == null) {
    return -1;
  }
  if (aGdd !== bGdd) {
    return aGdd - bGdd;
  }
  return a.id - b.id;
}

function sortStages(stages: CropStage[]): CropStage[] {
  return [...stages].sort((a, b) => a.order - b.order);
}

function unassignedLane(
  blueprints: CropTaskScheduleBlueprint[],
  drafts: Record<number, number | null>
): BlueprintStageLane {
  return {
    stageOrder: null,
    stageName: null,
    cumulativeGddStart: null,
    cumulativeGddEnd: null,
    gddRangeMissing: false,
    blueprints: [...blueprints].sort((a, b) => compareBlueprintsByGdd(a, b, drafts))
  };
}

export function groupBlueprintsByStage(
  stages: CropStage[],
  blueprints: CropTaskScheduleBlueprint[],
  blueprintGddDrafts: Record<number, number | null> = {}
): BlueprintStageLane[] {
  const sortedStages = sortStages(stages);

  if (sortedStages.length === 0) {
    return [unassignedLane(blueprints, blueprintGddDrafts)];
  }

  const cumulativeByOrder = buildStageCumulativeGddByOrder(sortedStages);
  const lanes: BlueprintStageLane[] = [
    {
      stageOrder: null,
      stageName: null,
      cumulativeGddStart: null,
      cumulativeGddEnd: null,
      gddRangeMissing: false,
      blueprints: []
    },
    ...sortedStages.map((stage) => {
      const range = cumulativeByOrder.get(stage.order);
      return {
        stageOrder: stage.order,
        stageName: stage.name,
        cumulativeGddStart: range?.cumulativeGddStart ?? null,
        cumulativeGddEnd: range?.cumulativeGddEnd ?? null,
        gddRangeMissing: range?.gddRangeMissing ?? true,
        blueprints: [] as CropTaskScheduleBlueprint[]
      };
    })
  ];

  for (const item of blueprints) {
    const lane =
      item.stage_order == null
        ? lanes[0]
        : lanes.find((entry) => entry.stageOrder === item.stage_order) ?? lanes[0];
    lane.blueprints.push(item);
  }

  for (const lane of lanes) {
    lane.blueprints.sort((a, b) => compareBlueprintsByGdd(a, b, blueprintGddDrafts));
  }

  return lanes.filter(
    (lane) => lane.stageOrder != null || lane.blueprints.length > 0
  );
}
