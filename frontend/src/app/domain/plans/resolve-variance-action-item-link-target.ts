import type { PlanVarianceActionItem } from './plan-vs-actual-summary';

export type VarianceActionLinkTarget = 'work' | 'learn';

export function resolveVarianceActionItemLinkTarget(
  item: PlanVarianceActionItem
): VarianceActionLinkTarget {
  if (item.exceedance_kind === 'days') {
    return 'work';
  }
  return 'learn';
}
