import { forkJoin, Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import {
  buildPlanInputGapSummary,
  PlanInputGapSummary
} from '../../domain/plans/build-plan-input-gap-summary';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import { PlanGateway } from './plan-gateway';

const ZERO_GAP: PlanInputGapSummary = {
  unrecordedCount: 0,
  actionRequiredCount: 0,
  structuredUnrecordedCount: 0,
  amountVarianceCount: 0
};

export function loadPlanListInputGapSummaries(
  plans: PlanSummary[],
  planGateway: PlanGateway
): Observable<Map<number, PlanInputGapSummary>> {
  if (plans.length === 0) {
    return of(new Map());
  }

  return forkJoin(
    plans.map((plan) =>
      planGateway.getPlanVsActualSummary(plan.id).pipe(
        map((summary) => ({
          planId: plan.id,
          inputGap: buildPlanInputGapSummary(summary)
        })),
        catchError(() =>
          of({
            planId: plan.id,
            inputGap: ZERO_GAP
          })
        )
      )
    )
  ).pipe(
    map((summaries) => new Map(summaries.map((entry) => [entry.planId, entry.inputGap])))
  );
}
