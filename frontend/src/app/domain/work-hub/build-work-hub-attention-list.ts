import type { PlanVarianceActionItem } from '../plans/plan-vs-actual-summary';

export type WorkHubAttentionLinkTarget = 'work' | 'learn';

export interface WorkHubAttentionItem {
  farmId: number;
  farmName: string;
  planId: number;
  itemId: number;
  taskName: string;
  linkTarget: WorkHubAttentionLinkTarget;
}

export interface WorkHubAttentionListInput {
  farmId: number;
  farmName: string;
  planId: number;
  actionItems: ReadonlyArray<PlanVarianceActionItem>;
}

export const DEFAULT_WORK_HUB_ATTENTION_LIMIT = 5;

const EXCEEDANCE_PRIORITY: Record<PlanVarianceActionItem['exceedance_kind'], number> = {
  both: 3,
  gdd: 2,
  days: 1
};

function attentionPriority(item: PlanVarianceActionItem): number {
  const kindScore = EXCEEDANCE_PRIORITY[item.exceedance_kind] * 1_000_000;
  const gddScore = Math.abs(item.gdd_delta ?? 0) * 1_000;
  const daysScore = Math.abs(item.delta_days ?? 0);
  return kindScore + gddScore + daysScore;
}

export function resolveWorkHubAttentionLinkTarget(
  item: PlanVarianceActionItem
): WorkHubAttentionLinkTarget {
  return item.exceedance_kind === 'days' ? 'learn' : 'work';
}

export function buildWorkHubAttentionList(
  inputs: ReadonlyArray<WorkHubAttentionListInput>,
  limit = DEFAULT_WORK_HUB_ATTENTION_LIMIT
): WorkHubAttentionItem[] {
  const ranked = inputs.flatMap((input) =>
    input.actionItems.map((item) => ({
      farmId: input.farmId,
      farmName: input.farmName,
      planId: input.planId,
      itemId: item.item_id,
      taskName: item.name,
      linkTarget: resolveWorkHubAttentionLinkTarget(item),
      priority: attentionPriority(item)
    }))
  );

  return ranked
    .sort((left, right) => {
      const priorityDiff = right.priority - left.priority;
      if (priorityDiff !== 0) {
        return priorityDiff;
      }
      if (left.farmId !== right.farmId) {
        return left.farmId - right.farmId;
      }
      return left.itemId - right.itemId;
    })
    .slice(0, limit)
    .map(({ priority: _priority, ...item }) => item);
}
