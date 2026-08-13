import type { CultivationData } from './cultivation-plan-data';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

export function filterVarianceActionItemsOnGantt(
  actionItems: ReadonlyArray<PlanVarianceActionItem>,
  cultivations: ReadonlyArray<CultivationData>
): PlanVarianceActionItem[] {
  const cultivationIds = new Set(cultivations.map((c) => c.id));
  return actionItems.filter((item) => cultivationIds.has(item.field_cultivation_id));
}
