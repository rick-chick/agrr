import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';
import { PendingNavigationRequest } from '../../core/view-effects/pending-navigation-view.effects';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import type { WorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';
import type { WorkHubAttentionList } from '../../domain/work-hub/build-work-hub-attention-list';
import type { WorkHubVarianceCoverageStats } from '../../domain/work-hub/build-work-hub-variance-coverage-stats';

export interface WorkHubViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: WorkHubFarmRow[];
  portfolioSummary: WorkHubPortfolioSummaryStats | null;
  varianceCoverage: WorkHubVarianceCoverageStats | null;
  attentionList: WorkHubAttentionList | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingNavigation: PendingNavigationRequest | null;
}

export interface WorkHubView {
  control: WorkHubViewState;
}
