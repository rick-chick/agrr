type GanttCultivationPlanAction = 'adjust' | 'add_crop' | 'add_field' | 'remove_field';

export function buildGanttCultivationPlanEndpoint(
  planType: 'private' | 'public',
  planId: number,
  action: GanttCultivationPlanAction,
  fieldId?: number
): string | null {
  const prefix =
    planType === 'public'
      ? '/api/v1/public_plans/cultivation_plans'
      : '/api/v1/plans/cultivation_plans';

  if (action === 'remove_field') {
    if (!fieldId) {
      return null;
    }
    return `${prefix}/${planId}/remove_field/${fieldId}`;
  }

  return `${prefix}/${planId}/${action}`;
}

export function ganttPrivatePlanDataPath(planId: number): string {
  return `/api/v1/plans/cultivation_plans/${planId}/data`;
}

export function ganttPublicPlanDataPath(planId: number): string {
  return `/api/v1/public_plans/cultivation_plans/${planId}/data`;
}
