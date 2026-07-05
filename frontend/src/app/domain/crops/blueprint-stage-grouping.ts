import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export interface BlueprintStageLane {
  stageOrder: number | null;
  stageName: string | null;
  blueprints: CropTaskScheduleBlueprint[];
}

function compareBlueprintsByGdd(
  a: CropTaskScheduleBlueprint,
  b: CropTaskScheduleBlueprint
): number {
  const aGdd = a.gdd_trigger;
  const bGdd = b.gdd_trigger;
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

export function groupBlueprintsByStage(
  stages: CropStage[],
  blueprints: CropTaskScheduleBlueprint[]
): BlueprintStageLane[] {
  const sortedStages = sortStages(stages);

  if (sortedStages.length === 0) {
    return [
      {
        stageOrder: null,
        stageName: null,
        blueprints: [...blueprints].sort(compareBlueprintsByGdd)
      }
    ];
  }

  const lanes: BlueprintStageLane[] = [
    { stageOrder: null, stageName: null, blueprints: [] },
    ...sortedStages.map((stage) => ({
      stageOrder: stage.order,
      stageName: stage.name,
      blueprints: [] as CropTaskScheduleBlueprint[]
    }))
  ];

  for (const item of blueprints) {
    const lane =
      item.stage_order == null
        ? lanes[0]
        : lanes.find((entry) => entry.stageOrder === item.stage_order) ?? lanes[0];
    lane.blueprints.push(item);
  }

  for (const lane of lanes) {
    lane.blueprints.sort(compareBlueprintsByGdd);
  }

  return lanes;
}
