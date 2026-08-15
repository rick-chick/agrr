import { variancePortfolioRowNeedsAttention } from '../work-variance-portfolio/variance-portfolio-row-needs-attention';
import type { VariancePortfolioRow } from '../work-variance-portfolio/variance-portfolio-row';

export interface WorkHubVarianceCoverageStats {
  farmCount: number;
  planCount: number;
}

export function buildWorkHubVarianceCoverageStats(
  rows: ReadonlyArray<VariancePortfolioRow>
): WorkHubVarianceCoverageStats {
  const attentionRows = rows.filter(variancePortfolioRowNeedsAttention);
  const farmIds = new Set(attentionRows.map((row) => row.farmId));
  return {
    farmCount: farmIds.size,
    planCount: attentionRows.length
  };
}
