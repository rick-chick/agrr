import type { VariancePortfolioFilters } from './variance-portfolio-filters';
import type { VariancePortfolioRow } from './variance-portfolio-row';

export function filterVariancePortfolioRows(
  rows: ReadonlyArray<VariancePortfolioRow>,
  filters: VariancePortfolioFilters
): VariancePortfolioRow[] {
  return rows.filter((row) => {
    if (filters.farmId != null && row.farmId !== filters.farmId) {
      return false;
    }
    if (filters.status != null && row.status !== filters.status) {
      return false;
    }
    if (filters.planYear != null && row.planYear !== filters.planYear) {
      return false;
    }
    return true;
  });
}
