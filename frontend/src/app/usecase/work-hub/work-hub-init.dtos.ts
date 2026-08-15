import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import type { WorkHubAttentionItem } from '../../domain/work-hub/build-work-hub-attention-list';
import type { WorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';

export interface WorkHubInitPresentDto {
  farms: WorkHubFarmRow[];
  portfolioSummary: WorkHubPortfolioSummaryStats;
  attentionItems: WorkHubAttentionItem[];
}
