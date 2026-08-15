import type { WorkHubAttentionList } from '../../domain/work-hub/build-work-hub-attention-list';
import type { VariancePortfolioFilterOptions } from '../../domain/work-variance-portfolio/collect-variance-portfolio-filter-options';
import type { VariancePortfolioFarmGroup } from '../../domain/work-variance-portfolio/group-variance-portfolio-by-farm';
import type { VariancePortfolioSummaryStats } from '../../domain/work-variance-portfolio/build-variance-portfolio-summary-stats';
import type { VariancePortfolioFilters } from '../../domain/work-variance-portfolio/variance-portfolio-filters';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';
import { EMPTY_VARIANCE_PORTFOLIO_FILTERS } from '../../domain/work-variance-portfolio/variance-portfolio-filters';

export interface WorkVarianceViewState {
  loading: boolean;
  error: string | null;
  rows: VariancePortfolioRow[];
  filters: VariancePortfolioFilters;
  filterOptions: VariancePortfolioFilterOptions;
  farmGroups: VariancePortfolioFarmGroup[];
  portfolioSummary: VariancePortfolioSummaryStats | null;
  attentionList: WorkHubAttentionList | null;
}

export const initialWorkVarianceViewState: WorkVarianceViewState = {
  loading: true,
  error: null,
  rows: [],
  filters: { ...EMPTY_VARIANCE_PORTFOLIO_FILTERS },
  filterOptions: { farms: [], statuses: [], planYears: [] },
  farmGroups: [],
  portfolioSummary: null,
  attentionList: null
};

export interface WorkVarianceView {
  control: WorkVarianceViewState;
}
