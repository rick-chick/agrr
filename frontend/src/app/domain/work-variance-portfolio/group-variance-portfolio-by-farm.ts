import type { VariancePortfolioRow } from './variance-portfolio-row';

export interface VariancePortfolioFarmGroup {
  farmId: number;
  farmName: string;
  plans: VariancePortfolioRow[];
}

function comparePlans(left: VariancePortfolioRow, right: VariancePortfolioRow): number {
  const leftYear = left.planYear ?? Number.NEGATIVE_INFINITY;
  const rightYear = right.planYear ?? Number.NEGATIVE_INFINITY;
  if (leftYear !== rightYear) {
    return rightYear - leftYear;
  }
  return left.planId - right.planId;
}

export function groupVariancePortfolioByFarm(
  rows: ReadonlyArray<VariancePortfolioRow>
): VariancePortfolioFarmGroup[] {
  const groups = new Map<number, VariancePortfolioFarmGroup>();

  for (const row of rows) {
    const existing = groups.get(row.farmId);
    if (existing) {
      existing.plans.push(row);
      continue;
    }
    groups.set(row.farmId, {
      farmId: row.farmId,
      farmName: row.farmName,
      plans: [row]
    });
  }

  return [...groups.values()]
    .sort((left, right) => left.farmId - right.farmId)
    .map((group) => ({
      ...group,
      plans: [...group.plans].sort(comparePlans)
    }));
}
