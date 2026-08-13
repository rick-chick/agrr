export type PlanWizardReturnTab = 'work' | 'task_schedule' | 'learn';

export function parsePlanWizardReturnTab(raw: string | null | undefined): PlanWizardReturnTab {
  if (raw === 'work') {
    return 'work';
  }
  if (raw === 'learn') {
    return 'learn';
  }
  return 'task_schedule';
}

export function planWizardReturnPath(
  planId: number,
  tab: PlanWizardReturnTab
): (string | number)[] {
  if (tab === 'work') {
    return ['/plans', planId, 'work'];
  }
  if (tab === 'learn') {
    return ['/plans', planId, 'learn'];
  }
  return ['/plans', planId, 'task_schedule'];
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

export function planLearnPostMasterReturnNavigation(planId: number): {
  commands: (string | number)[];
  queryParams: { followUp: 'post_master' };
} {
  return {
    commands: planWizardReturnPath(planId, 'learn'),
    queryParams: { followUp: 'post_master' }
  };
}
