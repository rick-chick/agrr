import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import type { WorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';
import type { WorkHubAttentionList } from '../../domain/work-hub/build-work-hub-attention-list';

export interface WorkHubInitPresentDto {
  farms: WorkHubFarmRow[];
  portfolioSummary: WorkHubPortfolioSummaryStats;
  attentionList: WorkHubAttentionList;
}
