export const PLAN_CARRYOVER_FROM_QUERY_PARAM = 'carryoverFrom';

export const PLAN_CARRYOVER_NEXT_PLAN_CTA_KEY = 'plans.carryover.next_plan_cta';

export function buildPlanNewCarryoverFromNavigation(sourcePlanId: number): {
  routerLink: string[];
  queryParams: Record<string, number>;
} {
  return {
    routerLink: ['/plans', 'new'],
    queryParams: { [PLAN_CARRYOVER_FROM_QUERY_PARAM]: sourcePlanId }
  };
}

export function parseCarryoverFromPlanId(raw: string | null | undefined): number | null {
  if (raw == null || raw === '') {
    return null;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}
