export interface VariancePortfolioFilters {
  farmId: number | null;
  status: string | null;
  planYear: number | null;
}

export const EMPTY_VARIANCE_PORTFOLIO_FILTERS: VariancePortfolioFilters = {
  farmId: null,
  status: null,
  planYear: null
};
