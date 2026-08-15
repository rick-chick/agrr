import { forkJoin, Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { buildPlanInputGapSummary } from '../../domain/plans/build-plan-input-gap-summary';
import type { PlanListEntry } from '../../domain/plans/plan-list-entry';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanGateway } from './plan-gateway';

export function loadPlanListInputGaps(
  plans: PlanSummary[],
  planGateway: PlanGateway
): Observable<PlanListEntry[]> {
  if (plans.length === 0) {
    return of([]);
  }

  return forkJoin(
    plans.map((plan) =>
      planGateway.getPlanVsActualSummary(plan.id).pipe(
        map((summary) => ({
          plan,
          inputGap: buildPlanInputGapSummary(summary)
        })),
        catchError(() => of({ plan, inputGap: null }))
      )
    )
  );
}
