import { Observable } from 'rxjs';
import { forkJoin, of } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  buildWorkHubAttentionList,
  type WorkHubAttentionList
} from '../../domain/work-hub/build-work-hub-attention-list';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';
import { PlanGateway } from '../plans/plan-gateway';

function rowNeedsAttention(row: VariancePortfolioRow): boolean {
  return (
    row.unrecordedCount > 0 ||
    row.gddDelayCount > 0 ||
    row.thresholdExceededCount > 0 ||
    row.daysThresholdExceededCount > 0
  );
}

export function loadVariancePortfolioAttentionItems(
  rows: ReadonlyArray<VariancePortfolioRow>,
  planGateway: PlanGateway
): Observable<WorkHubAttentionList> {
  const attentionRows = rows.filter(rowNeedsAttention);
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
