import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

export function findVarianceActionItemForScheduleItem(
  itemId: number,
  actionItems: ReadonlyArray<PlanVarianceActionItem>
): PlanVarianceActionItem | null {
  return actionItems.find((item) => item.item_id === itemId) ?? null;
}
