import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';
import { PendingNavigationRequest } from '../../core/view-effects/pending-navigation-view.effects';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import type { WorkHubAttentionItem } from '../../domain/work-hub/build-work-hub-attention-list';
import type { WorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';

export interface WorkHubViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: WorkHubFarmRow[];
  portfolioSummary: WorkHubPortfolioSummaryStats | null;
  attentionItems: WorkHubAttentionItem[];
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingNavigation: PendingNavigationRequest | null;
}

export interface WorkHubView {
  control: WorkHubViewState;
}
