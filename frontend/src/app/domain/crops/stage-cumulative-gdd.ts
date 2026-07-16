import type { CropStage } from './crop';
import { findDuplicateStageOrders } from './crop-stage-order';

export interface StageCumulativeGddRange {
  cumulativeGddStart: number | null;
  cumulativeGddEnd: number | null;
  gddRangeMissing: boolean;
}

function sortedStages(stages: CropStage[]): CropStage[] {
  return [...stages].sort((a, b) => a.order - b.order);
}

function parseRequiredGdd(value: unknown): number | null {
  if (value == null || value === '') {
    return null;
  }
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function stageCumulativeGddRange(
  stages: CropStage[],
  stageOrder: number
): StageCumulativeGddRange {
  const map = buildStageCumulativeGddByOrder(stages);
  return (
    map.get(stageOrder) ?? {
      cumulativeGddStart: null,
      cumulativeGddEnd: null,
      gddRangeMissing: true
    }
  );
}

export function buildStageCumulativeGddByOrder(
  stages: CropStage[]
): Map<number, StageCumulativeGddRange> {
  const map = new Map<number, StageCumulativeGddRange>();
  const missingRange: StageCumulativeGddRange = {
    cumulativeGddStart: null,
    cumulativeGddEnd: null,
    gddRangeMissing: true
  };

  if (findDuplicateStageOrders(stages).length > 0) {
    for (const cropStage of stages) {
      map.set(cropStage.order, missingRange);
    }
    return map;
  }

  let cumulative = 0;

  for (const cropStage of sortedStages(stages)) {
    const requiredGdd = parseRequiredGdd(cropStage.thermal_requirement?.required_gdd);
    if (requiredGdd == null) {
      map.set(cropStage.order, {
        cumulativeGddStart: null,
        cumulativeGddEnd: null,
        gddRangeMissing: true
      });
      continue;
    }

    const start = cumulative;
    cumulative += requiredGdd;
    map.set(cropStage.order, {
      cumulativeGddStart: start,
      cumulativeGddEnd: cumulative,
      gddRangeMissing: false
    });
  }

  return map;
}
