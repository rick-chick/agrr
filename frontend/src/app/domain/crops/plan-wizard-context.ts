export type PlanWizardReturnTab = 'work' | 'task_schedule';

export function parsePlanWizardReturnTab(raw: string | null | undefined): PlanWizardReturnTab {
  return raw === 'work' ? 'work' : 'task_schedule';
}

export function planWizardReturnPath(
  planId: number,
  tab: PlanWizardReturnTab
): (string | number)[] {
  return tab === 'work' ? ['/plans', planId, 'work'] : ['/plans', planId, 'task_schedule'];
}

export interface CropPlanWizardQueryParams {
  fromPlan: number;
  returnTo: PlanWizardReturnTab;
}

export function cropPlanWizardQueryParams(
  fromPlanId: number,
  returnTab: PlanWizardReturnTab
): CropPlanWizardQueryParams {
  return { fromPlan: fromPlanId, returnTo: returnTab };
}
