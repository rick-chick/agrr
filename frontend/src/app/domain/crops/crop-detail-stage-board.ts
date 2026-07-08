import {
  buildBlueprintDetailSummary,
  type BlueprintDetailSummary,
  type BlueprintDetailSummaryGddGroup
} from './blueprint-detail-summary';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';
import { stageCumulativeGddRange } from './stage-cumulative-gdd';

export type CropDetailStageColumn = {
  stageOrder: number | null;
  stageName: string | null;
  requiredGdd: number | null;
  optimalMin: number | null;
  optimalMax: number | null;
  cumulativeGddStart: number | null;
  cumulativeGddEnd: number | null;
  gddRangeMissing: boolean;
  outOfRangeCount: number;
  gddGroups: BlueprintDetailSummaryGddGroup[];
};

export type CropDetailStageBoard = {
  columns: CropDetailStageColumn[];
};

function parseRequiredGdd(value: unknown): number | null {
  if (value == null || value === '') {
    return null;
  }
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function sortedStages(stages: CropStage[]): CropStage[] {
  return [...stages].sort((a, b) => a.order - b.order);
}

export function buildCropDetailStageBoard(
  stages: CropStage[],
  blueprints: CropTaskScheduleBlueprint[],
  blueprintSummary: BlueprintDetailSummary = buildBlueprintDetailSummary(stages, blueprints)
): CropDetailStageBoard {
  const summary = blueprintSummary;
  const laneByOrder = new Map(
    summary.lanes
      .filter((lane) => lane.stageOrder != null)
      .map((lane) => [lane.stageOrder as number, lane])
  );

  const columns: CropDetailStageColumn[] = sortedStages(stages).map((cropStage) => {
    const lane = laneByOrder.get(cropStage.order);
    const range = stageCumulativeGddRange(stages, cropStage.order);

    return {
      stageOrder: cropStage.order,
      stageName: cropStage.name,
      requiredGdd: parseRequiredGdd(cropStage.thermal_requirement?.required_gdd),
      optimalMin: cropStage.temperature_requirement?.optimal_min ?? null,
      optimalMax: cropStage.temperature_requirement?.optimal_max ?? null,
      cumulativeGddStart: range.cumulativeGddStart,
      cumulativeGddEnd: range.cumulativeGddEnd,
      gddRangeMissing: range.gddRangeMissing,
      outOfRangeCount: lane?.outOfRangeCount ?? 0,
      gddGroups: lane?.gddGroups ?? []
    };
  });

  const unassignedLane = summary.lanes.find((lane) => lane.stageOrder == null);
  if (unassignedLane) {
    columns.push({
      stageOrder: null,
      stageName: null,
      requiredGdd: null,
      optimalMin: null,
      optimalMax: null,
      cumulativeGddStart: null,
      cumulativeGddEnd: null,
      gddRangeMissing: false,
      outOfRangeCount: unassignedLane.outOfRangeCount,
      gddGroups: unassignedLane.gddGroups
    });
  }

  return { columns };
}
