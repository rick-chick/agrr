import type { PlanListFarmGroup } from './plan-list-farm-group';
import type { PlanListPlan } from './plan-list-plan';

function farmNameForPlan(plan: PlanListPlan): string {
  const trimmed = plan.farm_name?.trim();
  if (trimmed) {
    return trimmed;
  }
  return `Farm #${plan.farm_id}`;
}

function comparePlansWithinFarm(left: PlanListPlan, right: PlanListPlan): number {
  const leftYear = left.plan_year ?? -1;
  const rightYear = right.plan_year ?? -1;
  if (leftYear !== rightYear) {
    return rightYear - leftYear;
  }
  return left.id - right.id;
}

export function buildPlanListFarmGroups(plans: PlanListPlan[]): PlanListFarmGroup[] {
  const byFarmId = new Map<number, PlanListPlan[]>();

  for (const plan of plans) {
    const bucket = byFarmId.get(plan.farm_id);
    if (bucket) {
      bucket.push(plan);
    } else {
      byFarmId.set(plan.farm_id, [plan]);
    }
  }

  return [...byFarmId.entries()]
    .map(([farmId, farmPlans]) => ({
      farmId,
      farmName: farmNameForPlan(farmPlans[0]),
      plans: [...farmPlans].sort(comparePlansWithinFarm)
    }))
    .sort((left, right) => left.farmName.localeCompare(right.farmName, undefined, { sensitivity: 'base' }));
}
