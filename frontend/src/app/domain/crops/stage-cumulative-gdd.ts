import type { CropStage } from './crop';

export interface StageCumulativeGddRange {
  cumulativeGddStart: number | null;
  cumulativeGddEnd: number | null;
  gddRangeMissing: boolean;
}

function sortedStages(stages: CropStage[]): CropStage[] {
  return [...stages].sort((a, b) => a.order - b.order);
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
  let cumulative = 0;

  for (const cropStage of sortedStages(stages)) {
    const requiredGdd = cropStage.thermal_requirement?.required_gdd;
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
