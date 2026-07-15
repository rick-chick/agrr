import { describe, expect, it } from 'vitest';
import {
  applyStageListReorder,
  findDuplicateStageOrders,
  reorderStagesByIndex,
  sortStagesByOrder
} from './crop-stage-order';
import type { CropStage } from './crop';

function stage(id: number, order: number, name = `Stage ${order}`): CropStage {
  return {
    id,
    crop_id: 1,
    name,
    order
  };
}

describe('sortStagesByOrder', () => {
  it('returns stages sorted ascending by order', () => {
    const sorted = sortStagesByOrder([stage(2, 2), stage(1, 1), stage(3, 3)]);
    expect(sorted.map((s) => s.id)).toEqual([1, 2, 3]);
  });
});

describe('findDuplicateStageOrders', () => {
  it('returns empty array when all orders are unique', () => {
    expect(findDuplicateStageOrders([stage(1, 1), stage(2, 2)])).toEqual([]);
  });

  it('returns duplicate order values', () => {
    expect(findDuplicateStageOrders([stage(1, 1), stage(2, 1), stage(3, 2), stage(4, 2)])).toEqual([
      1, 2
    ]);
  });
});

describe('reorderStagesByIndex', () => {
  it('moves a stage and reassigns sequential orders starting at 1', () => {
    const stages = [stage(1, 1), stage(2, 2), stage(3, 3)];
    const result = reorderStagesByIndex(stages, 0, 2);

    expect(result.stages.map((s) => ({ id: s.id, order: s.order }))).toEqual([
      { id: 2, order: 1 },
      { id: 3, order: 2 },
      { id: 1, order: 3 }
    ]);
    expect(result.updates).toEqual([
      { id: 1, order: 3 },
      { id: 2, order: 1 },
      { id: 3, order: 2 }
    ]);
  });

  it('returns no updates when drop index equals previous index', () => {
    const stages = [stage(1, 1), stage(2, 2)];
    const result = reorderStagesByIndex(stages, 1, 1);

    expect(result.updates).toEqual([]);
    expect(result.stages.map((s) => s.order)).toEqual([1, 2]);
  });
});

describe('applyStageListReorder', () => {
  it('updates only stages whose order changed', () => {
    const stages = [stage(1, 1), stage(2, 2), stage(3, 3)];
    const reordered = [stage(2, 2), stage(1, 1), stage(3, 3)];
    const result = applyStageListReorder(stages, reordered);

    expect(result.updates).toEqual([
      { id: 1, order: 2 },
      { id: 2, order: 1 }
    ]);
    expect(result.stages.find((s) => s.id === 3)?.order).toBe(3);
  });
});
