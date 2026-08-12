import type { CultivationData } from './cultivation-plan-data';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

export function filterVarianceActionItemsOnGantt(
  actionItems: ReadonlyArray<PlanVarianceActionItem>,
  cultivations: ReadonlyArray<CultivationData>
): PlanVarianceActionItem[] {
  const cultivationIds = new Set(cultivations.map((c) => c.id));
  return actionItems.filter((item) => cultivationIds.has(item.field_cultivation_id));
}

export function uniqueFieldCultivationIds(
  actionItems: ReadonlyArray<PlanVarianceActionItem>
): number[] {
  const seen = new Set<number>();
  const ids: number[] = [];
  for (const item of actionItems) {
    if (!seen.has(item.field_cultivation_id)) {
      seen.add(item.field_cultivation_id);
      ids.push(item.field_cultivation_id);
    }
  }
  return ids;
}
