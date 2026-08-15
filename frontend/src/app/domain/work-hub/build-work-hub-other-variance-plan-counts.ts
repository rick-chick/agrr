import { variancePortfolioRowNeedsAttention } from '../work-variance-portfolio/variance-portfolio-row-needs-attention';
import type { VariancePortfolioRow } from '../work-variance-portfolio/variance-portfolio-row';

export interface WorkHubFarmPlanReference {
  farmId: number;
  planId: number | null;
}

export function buildWorkHubOtherVariancePlanCounts(
  rows: ReadonlyArray<VariancePortfolioRow>,
  farms: ReadonlyArray<WorkHubFarmPlanReference>
): Map<number, number> {
  const counts = new Map<number, number>();

  for (const farm of farms) {
    if (farm.planId == null) {
      counts.set(farm.farmId, 0);
      continue;
    }

    const otherCount = rows.filter(
      (row) =>
        row.farmId === farm.farmId &&
        variancePortfolioRowNeedsAttention(row) &&
        row.planId !== farm.planId
    ).length;
    counts.set(farm.farmId, otherCount);
  }

  return counts;
}
