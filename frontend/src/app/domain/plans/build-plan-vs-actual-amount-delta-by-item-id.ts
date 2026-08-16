import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export function buildPlanVsActualAmountDeltaByItemId(
  summary: PlanVsActualSummary | null | undefined
): Record<number, number> {
  if (!summary) {
    return {};
  }

  const deltas: Record<number, number> = {};
  for (const item of summary.top_variance_items) {
    if (item.amount_delta != null) {
      deltas[item.item_id] = item.amount_delta;
    }
  }
  for (const item of summary.action_required_items ?? []) {
    if (item.amount_delta != null) {
      deltas[item.item_id] = item.amount_delta;
    }
  }
  return deltas;
}
