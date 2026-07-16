import { describe, expect, it } from 'vitest';
import { buildStageCumulativeGddByOrder, stageCumulativeGddRange } from './stage-cumulative-gdd';
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

describe('stageCumulativeGddRange', () => {
  it('returns start 0 and end as required_gdd for the first stage', () => {
    const range = stageCumulativeGddRange([stage(1, 200), stage(2, 300)], 1);
    expect(range).toEqual({ cumulativeGddStart: 0, cumulativeGddEnd: 200, gddRangeMissing: false });
  });

  it('returns cumulative start and end for later stages', () => {
    const range = stageCumulativeGddRange(
      [stage(1, 200), stage(2, 300), stage(3, 100)],
      2
    );
    expect(range).toEqual({ cumulativeGddStart: 200, cumulativeGddEnd: 500, gddRangeMissing: false });
  });

  it('marks range missing when required_gdd is unset', () => {
    const range = stageCumulativeGddRange([stage(1, 200), stage(2, null)], 2);
    expect(range.gddRangeMissing).toBe(true);
    expect(range.cumulativeGddStart).toBeNull();
    expect(range.cumulativeGddEnd).toBeNull();
  });

  it('marks range missing when duplicate stage orders exist', () => {
    const stages = [stage(1, 200), { ...stage(1, 300), id: 2 }];
    const range = stageCumulativeGddRange(stages, 1);
    expect(range.gddRangeMissing).toBe(true);
    expect(range.cumulativeGddStart).toBeNull();
    expect(range.cumulativeGddEnd).toBeNull();
  });
});

describe('buildStageCumulativeGddByOrder', () => {
  it('maps each stage order to its cumulative range', () => {
    const map = buildStageCumulativeGddByOrder([stage(2, 100), stage(1, 200)]);
    expect(map.get(1)).toEqual({
      cumulativeGddStart: 0,
      cumulativeGddEnd: 200,
      gddRangeMissing: false
    });
    expect(map.get(2)).toEqual({
      cumulativeGddStart: 200,
      cumulativeGddEnd: 300,
      gddRangeMissing: false
    });
  });

  it('marks all ranges missing when stage orders are duplicated', () => {
    const stages = [
      stage(1, 200, 'Stage A'),
      { ...stage(1, 300, 'Stage B'), id: 2 },
      stage(2, 100, 'Stage C')
    ];

    const map = buildStageCumulativeGddByOrder(stages);
    expect(map.get(1)).toEqual({
      cumulativeGddStart: null,
      cumulativeGddEnd: null,
      gddRangeMissing: true
    });
    expect(map.get(2)).toEqual({
      cumulativeGddStart: null,
      cumulativeGddEnd: null,
      gddRangeMissing: true
    });
  });

  it('coerces string required_gdd from API/forms to numbers when summing', () => {
    const stages: CropStage[] = [
      {
        id: 1,
        crop_id: 1,
        name: 'Stage 1',
        order: 1,
        thermal_requirement: {
          id: 1,
          crop_stage_id: 1,
          required_gdd: '800' as unknown as number
        }
      },
      {
        id: 2,
        crop_id: 1,
        name: 'Stage 2',
        order: 2,
        thermal_requirement: {
          id: 2,
          crop_stage_id: 2,
          required_gdd: '800' as unknown as number
        }
      }
    ];

    const map = buildStageCumulativeGddByOrder(stages);
    expect(map.get(1)).toEqual({
      cumulativeGddStart: 0,
      cumulativeGddEnd: 800,
      gddRangeMissing: false
    });
    expect(map.get(2)).toEqual({
      cumulativeGddStart: 800,
      cumulativeGddEnd: 1600,
      gddRangeMissing: false
    });
  });
});
