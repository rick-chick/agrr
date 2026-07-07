import { describe, expect, it } from 'vitest';
import { blueprintLaneId } from './crop-blueprint-lane-id';
import type { BlueprintStageLane } from '../../domain/crops/blueprint-stage-grouping';

function lane(stageOrder: number | null): BlueprintStageLane {
  return {
    stageOrder,
    stageName: stageOrder == null ? null : `Stage ${stageOrder}`,
    cumulativeGddStart: null,
    cumulativeGddEnd: null,
    gddRangeMissing: false,
    blueprints: []
  };
}

describe('blueprintLaneId', () => {
  it('returns unassigned id when stageOrder is null', () => {
    expect(blueprintLaneId(lane(null))).toBe('blueprint-lane-unassigned');
  });

  it('returns stage-specific id when stageOrder is set', () => {
    expect(blueprintLaneId(lane(2))).toBe('blueprint-lane-2');
  });
});
