import { of } from 'rxjs';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import type { PlanGateway } from './plan-gateway';

export const EMPTY_PLAN_VS_ACTUAL_SUMMARY: PlanVsActualSummary = {
  plan_id: 0,
  unrecorded_count: 0,
  categories: [],
  top_variance_items: []
};

export function planGatewayPlanVsActualStub(
  summary: PlanVsActualSummary = EMPTY_PLAN_VS_ACTUAL_SUMMARY
): Pick<PlanGateway, 'getPlanVsActualSummary'> {
  return {
    getPlanVsActualSummary: () => of(summary)
  };
}
