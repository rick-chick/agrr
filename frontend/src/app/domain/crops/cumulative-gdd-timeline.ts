import type { CropStage } from './crop';
import { buildStageCumulativeGddByOrder } from './stage-cumulative-gdd';

export interface CumulativeGddTimelineSegment {
  stageOrder: number;
  stageName: string;
  cumulativeGddStart: number;
  cumulativeGddEnd: number;
}

export function cumulativeGddTimelineSegments(
  stages: CropStage[]
): CumulativeGddTimelineSegment[] {
  const cumulativeByOrder = buildStageCumulativeGddByOrder(stages);
  const segments: CumulativeGddTimelineSegment[] = [];

  for (const cropStage of [...stages].sort((a, b) => a.order - b.order)) {
    const range = cumulativeByOrder.get(cropStage.order);
    if (!range || range.gddRangeMissing) {
      continue;
    }
    segments.push({
      stageOrder: cropStage.order,
      stageName: cropStage.name,
      cumulativeGddStart: range.cumulativeGddStart!,
      cumulativeGddEnd: range.cumulativeGddEnd!
    });
  }

  return segments;
}

export function gddAxisTotalGdd(segments: CumulativeGddTimelineSegment[]): number {
  if (!segments.length) {
    return 0;
  }
  return segments[segments.length - 1].cumulativeGddEnd;
}
