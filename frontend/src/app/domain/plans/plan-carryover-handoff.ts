export const PLAN_CARRYOVER_FROM_QUERY_PARAM = 'carryoverFrom';

export const PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY = 'plans.carryover.next_plan_cta';
export const PLAN_CARRYOVER_NEXT_PLAN_HINT_KEY = 'plans.carryover.next_plan_hint';

export function buildPlanNewCarryoverFromNavigation(sourcePlanId: number): {
  routerLink: (string | number)[];
  queryParams: Record<string, number>;
} {
  return {
    routerLink: ['/plans', 'new'],
    queryParams: { [PLAN_CARRYOVER_FROM_QUERY_PARAM]: sourcePlanId }
  };
}

export function planCarryoverNextPlanCtaVisible(input: {
  hasLearningSnapshot: boolean;
  loopComplete: boolean;
}): boolean {
  return input.hasLearningSnapshot || input.loopComplete;
}
