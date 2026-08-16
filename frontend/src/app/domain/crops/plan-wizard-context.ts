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
  handoffHighlightStageOrder?: number;
}

export interface CropPlanWizardQueryOptions {
  handoffHighlightStageOrder?: number | null;
}

export function cropPlanWizardQueryParams(
  fromPlanId: number,
  returnTab: PlanWizardReturnTab,
  options?: CropPlanWizardQueryOptions
): CropPlanWizardQueryParams {
  const params: CropPlanWizardQueryParams = { fromPlan: fromPlanId, returnTo: returnTab };
  if (options?.handoffHighlightStageOrder != null) {
    params.handoffHighlightStageOrder = options.handoffHighlightStageOrder;
  }
  return params;
}

export function parseHandoffHighlightStageOrder(raw: string | null | undefined): number | null {
  if (raw == null || raw === '') {
    return null;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed < 1) {
    return null;
  }
  return parsed;
}
