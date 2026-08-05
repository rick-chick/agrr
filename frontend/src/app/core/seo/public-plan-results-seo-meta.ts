import type { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

export interface PublicPlanResultsSeoLabels {
  planLabel: string;
  cropLabels: string;
  planYear: number;
  totalArea: number;
}

/** @internal exported for unit tests */
export function extractPublicPlanResultsSeoLabels(data: CultivationPlanData): PublicPlanResultsSeoLabels {
  const cropNames = (data.data.crops ?? []).map((crop) => crop.name).filter(Boolean);
  const cropLabels = cropNames.join(', ');
  const planName = data.data.plan_name?.trim() ?? '';
  const planLabel = planName || cropLabels || `Plan #${data.data.id}`;

  return {
    planLabel,
    cropLabels,
    planYear: data.data.plan_year,
    totalArea: data.data.total_area
  };
}

/** Share URL including planId query (OGP canonical / og:url). */
export function buildPublicPlanResultsShareUrl(origin: string, planId: number): string {
  if (!origin || !planId) {
    return '';
  }
  return `${origin}/public-plans/results?planId=${planId}`;
}
