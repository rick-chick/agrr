import type { PlanListPlan } from './plan-list-plan';

export interface PlanListFarmGroup {
  farmId: number;
  farmName: string;
  plans: PlanListPlan[];
}
