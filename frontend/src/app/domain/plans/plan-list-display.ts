import type { PlanListPlan } from './plan-list-plan';

const JAPANESE_FARM_PLAN_SUFFIX = /^(.+)の計画$/u;
const LEGACY_YEAR_SUFFIX = /^(.+) \((\d{4})\)$/u;

export function planListFarmName(plan: PlanListPlan): string | null {
  const trimmed = plan.farm_name?.trim();
  return trimmed ? trimmed : null;
}

function farmNameForSort(plan: PlanListPlan): string {
  return planListFarmName(plan) ?? `Farm #${plan.farm_id}`;
}

function comparePlansWithinFarm(left: PlanListPlan, right: PlanListPlan): number {
  const leftYear = left.plan_year ?? -1;
  const rightYear = right.plan_year ?? -1;
  if (leftYear !== rightYear) {
    return rightYear - leftYear;
  }
  return left.id - right.id;
}

export function planListCardTitle(plan: PlanListPlan, farmIdFallbackLabel: string): string {
  return planListFarmName(plan) ?? farmIdFallbackLabel;
}

function isDefaultPlanNameForFarm(plan: PlanListPlan): boolean {
  const farmName = plan.farm_name?.trim() ?? '';
  const storedName = plan.name?.trim() ?? '';
  if (!storedName) {
    return true;
  }
  if (!farmName) {
    return false;
  }
  if (storedName === farmName) {
    return true;
  }

  let base = storedName;
  const yearMatch = base.match(LEGACY_YEAR_SUFFIX);
  if (yearMatch) {
    base = yearMatch[1];
  }

  const farmMatch = base.match(JAPANESE_FARM_PLAN_SUFFIX);
  if (farmMatch && farmMatch[1].trim() === farmName) {
    return true;
  }

  if (base === farmName) {
    return true;
  }

  return false;
}

export function shouldShowCustomPlanName(plan: PlanListPlan): boolean {
  const storedName = plan.name?.trim() ?? '';
  if (!storedName) {
    return false;
  }
  return !isDefaultPlanNameForFarm(plan);
}

export function sortPlansForList(plans: PlanListPlan[]): PlanListPlan[] {
  const byFarmId = new Map<number, PlanListPlan[]>();

  for (const plan of plans) {
    const bucket = byFarmId.get(plan.farm_id);
    if (bucket) {
      bucket.push(plan);
    } else {
      byFarmId.set(plan.farm_id, [plan]);
    }
  }

  const farmEntries = [...byFarmId.entries()].map(([farmId, farmPlans]) => ({
    farmId,
    farmName: farmNameForSort(farmPlans[0]),
    plans: [...farmPlans].sort(comparePlansWithinFarm)
  }));

  farmEntries.sort((left, right) =>
    left.farmName.localeCompare(right.farmName, undefined, { sensitivity: 'base' })
  );

  return farmEntries.flatMap((entry) => entry.plans);
}
