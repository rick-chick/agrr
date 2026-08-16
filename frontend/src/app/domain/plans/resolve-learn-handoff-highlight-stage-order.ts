import { parseHandoffHighlightStageOrder } from '../crops/plan-wizard-context';
import { readLearnBpAmountApplyContext } from './learn-proposal-application-progress';

export function resolveLearnHandoffHighlightStageOrder(
  queryRaw: string | null | undefined,
  planId: number | null,
  cropId: number
): number | null {
  const fromQuery = parseHandoffHighlightStageOrder(queryRaw);
  if (fromQuery != null) {
    return fromQuery;
  }
  if (planId == null) {
    return null;
  }
  return readLearnBpAmountApplyContext(planId, cropId)?.stageOrder ?? null;
}
