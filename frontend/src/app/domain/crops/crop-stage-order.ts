import type { CropStage } from './crop';

export interface StageOrderUpdate {
  id: number;
  order: number;
}

export interface StageReorderResult {
  stages: CropStage[];
  updates: StageOrderUpdate[];
}

export function sortStagesByOrder(stages: CropStage[]): CropStage[] {
  return [...stages].sort((a, b) => a.order - b.order);
}

export function findDuplicateStageOrders(stages: CropStage[]): number[] {
  const seen = new Set<number>();
  const duplicates = new Set<number>();

  for (const stage of stages) {
    if (seen.has(stage.order)) {
      duplicates.add(stage.order);
    }
    seen.add(stage.order);
  }

  return [...duplicates].sort((a, b) => a - b);
}

export function applyStageListReorder(
  stages: CropStage[],
  reorderedStages: CropStage[]
): StageReorderResult {
  const newOrders = new Map(reorderedStages.map((stage, index) => [stage.id, index + 1]));
  const updates: StageOrderUpdate[] = [];

  const nextStages = stages.map((stage) => {
    const newOrder = newOrders.get(stage.id);
    if (newOrder == null || newOrder === stage.order) {
      return stage;
    }
    updates.push({ id: stage.id, order: newOrder });
    return { ...stage, order: newOrder };
  });

  return {
    stages: sortStagesByOrder(nextStages),
    updates: [...updates].sort((a, b) => a.id - b.id)
  };
}

export function reorderStagesByIndex(
  stages: CropStage[],
  previousIndex: number,
  currentIndex: number
): StageReorderResult {
  if (previousIndex === currentIndex) {
    return { stages: sortStagesByOrder(stages), updates: [] };
  }

  const sorted = sortStagesByOrder(stages);
  const reordered = [...sorted];
  const [moved] = reordered.splice(previousIndex, 1);
  reordered.splice(currentIndex, 0, moved);

  return applyStageListReorder(stages, reordered);
}
