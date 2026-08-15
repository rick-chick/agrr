import { Observable } from 'rxjs';
import { forkJoin, of } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  buildWorkHubAttentionList,
  type WorkHubAttentionList
} from '../../domain/work-hub/build-work-hub-attention-list';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';
import { variancePortfolioRowNeedsAttention } from '../../domain/work-variance-portfolio/variance-portfolio-row-needs-attention';
import { PlanGateway } from '../plans/plan-gateway';

export function loadVariancePortfolioAttentionItems(
  rows: ReadonlyArray<VariancePortfolioRow>,
  planGateway: PlanGateway
): Observable<WorkHubAttentionList> {
  const attentionRows = rows.filter(variancePortfolioRowNeedsAttention);
  if (!attentionRows.length) {
    return of({ items: [] });
  }

  return forkJoin(
    attentionRows.map((row) =>
      planGateway.getPlanVsActualSummary(row.planId).pipe(
        map((summary) => ({
          farmId: row.farmId,
          farmName: row.farmName,
          planId: row.planId,
          actionItems: summary.action_required_items ?? []
        }))
      )
    )
  ).pipe(map((sources) => buildWorkHubAttentionList(sources)));
}
