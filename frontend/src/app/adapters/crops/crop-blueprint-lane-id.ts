import type { BlueprintStageLane } from '../../domain/crops/blueprint-stage-grouping';

export function blueprintLaneId(lane: BlueprintStageLane): string {
  return lane.stageOrder == null ? 'blueprint-lane-unassigned' : `blueprint-lane-${lane.stageOrder}`;
}
