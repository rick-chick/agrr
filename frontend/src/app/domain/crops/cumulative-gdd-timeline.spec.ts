import { describe, expect, it } from 'vitest';
import { cumulativeGddTimelineSegments } from './cumulative-gdd-timeline';
import type { CropStage } from './crop';

function stage(
  order: number,
  requiredGdd: number | null | undefined,
  name = `Stage ${order}`
): CropStage {
  return {
    id: order,
    crop_id: 1,
    name,
    order,
    thermal_requirement:
      requiredGdd == null
        ? undefined
        : { id: order, crop_stage_id: order, required_gdd: requiredGdd }
  };
}

describe('cumulativeGddTimelineSegments', () => {
  it('returns cumulative GDD bands for stages with required_gdd in order', () => {
    const segments = cumulativeGddTimelineSegments([
      stage(2, 100, '生育期'),
      stage(1, 200, '定植期')
    ]);
    expect(segments).toEqual([
      {
        stageOrder: 1,
        stageName: '定植期',
        cumulativeGddStart: 0,
        cumulativeGddEnd: 200
      },
      {
        stageOrder: 2,
        stageName: '生育期',
        cumulativeGddStart: 200,
        cumulativeGddEnd: 300
      }
    ]);
  });

  it('skips stages with missing required_gdd', () => {
    const segments = cumulativeGddTimelineSegments([
      stage(1, 200, '定植期'),
      stage(2, null, '未設定'),
      stage(3, 100, '収穫期')
    ]);
    expect(segments).toEqual([
      {
        stageOrder: 1,
        stageName: '定植期',
        cumulativeGddStart: 0,
        cumulativeGddEnd: 200
      },
      {
        stageOrder: 3,
        stageName: '収穫期',
        cumulativeGddStart: 200,
        cumulativeGddEnd: 300
      }
    ]);
  });

  it('returns an empty array when no stage has required_gdd', () => {
    expect(cumulativeGddTimelineSegments([stage(1, null), stage(2, undefined)])).toEqual([]);
  });
});
