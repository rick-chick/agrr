import { forkJoin, Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import type { PlanGateway } from '../../usecase/plans/plan-gateway';
import { buildPlanInputGapSummary } from './build-plan-input-gap-summary';
import type { PlanListEntry } from './plan-list-entry';
import type { PlanSummary } from './plan-summary';

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
