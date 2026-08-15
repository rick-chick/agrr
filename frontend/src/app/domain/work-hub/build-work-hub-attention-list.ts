import { resolveVarianceActionItemLinkTarget } from '../plans/resolve-variance-action-item-link-target';
import type { PlanVarianceActionItem } from '../plans/plan-vs-actual-summary';
import type { VarianceActionLinkTarget } from '../plans/resolve-variance-action-item-link-target';

export interface HubFarmAttentionSource {
  farmId: number;
  farmName: string;
  planId: number;
  actionItems: ReadonlyArray<PlanVarianceActionItem>;
}

export interface WorkHubAttentionItem {
  farmId: number;
  farmName: string;
  planId: number;
  itemId: number;
  taskName: string;
  linkTarget: VarianceActionLinkTarget;
}

export interface WorkHubAttentionList {
  items: WorkHubAttentionItem[];
}

const DEFAULT_ATTENTION_LIMIT = 5;

function attentionPriority(item: PlanVarianceActionItem): number {
  return Math.abs(item.delta_days ?? 0) * 1000 + Math.abs(item.gdd_delta ?? 0);
}

export function buildWorkHubAttentionList(
  sources: ReadonlyArray<HubFarmAttentionSource>,
  limit = DEFAULT_ATTENTION_LIMIT
): WorkHubAttentionList {
  const candidates: Array<WorkHubAttentionItem & { priority: number }> = [];

  for (const source of sources) {
    for (const item of source.actionItems) {
      candidates.push({
        farmId: source.farmId,
        farmName: source.farmName,
        planId: source.planId,
        itemId: item.item_id,
        taskName: item.name,
        linkTarget: resolveVarianceActionItemLinkTarget(item),
        priority: attentionPriority(item)
      });
    }
  }

  const sorted = [...candidates].sort((left, right) => {
    const priorityDiff = right.priority - left.priority;
    if (priorityDiff !== 0) {
      return priorityDiff;
    }
    const farmDiff = left.farmId - right.farmId;
    if (farmDiff !== 0) {
      return farmDiff;
    }
    return left.itemId - right.itemId;
  });

  return {
    items: sorted.slice(0, limit).map(({ priority: _priority, ...item }) => item)
  };
}
