import type { VariancePortfolioRow } from './variance-portfolio-row';

export interface VariancePortfolioFarmOption {
  farmId: number;
  farmName: string;
}

export interface VariancePortfolioFilterOptions {
  farms: VariancePortfolioFarmOption[];
  statuses: string[];
  planYears: number[];
}

export function collectVariancePortfolioFilterOptions(
  rows: ReadonlyArray<VariancePortfolioRow>
): VariancePortfolioFilterOptions {
  const farms = new Map<number, VariancePortfolioFarmOption>();
  const statuses = new Set<string>();
  const planYears = new Set<number>();

  for (const row of rows) {
    farms.set(row.farmId, { farmId: row.farmId, farmName: row.farmName });
    statuses.add(row.status);
    if (row.planYear != null) {
      planYears.add(row.planYear);
    }
  }

  return {
    farms: [...farms.values()].sort((left, right) => left.farmId - right.farmId),
    statuses: [...statuses].sort(),
    planYears: [...planYears].sort((left, right) => right - left)
  };
}
