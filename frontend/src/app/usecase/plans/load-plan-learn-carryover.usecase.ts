import { HttpErrorResponse } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { catchError, map, Observable, of, switchMap } from 'rxjs';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class LoadPlanLearnCarryoverUseCase {
  constructor(@Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway) {}

  loadFarmContext(
    planId: number
  ): Observable<{ farmId: number; sourcePlans: PlanSummary[] }> {
    return this.planGateway.fetchPlan(planId).pipe(
      switchMap((plan) =>
        this.planGateway.listPlans().pipe(
          map((plans) => ({
            farmId: plan.farm_id,
            sourcePlans: plans.filter(
              (candidate) => candidate.farm_id === plan.farm_id && candidate.id !== planId
            )
          })),
          catchError(() =>
            of({
              farmId: plan.farm_id,
              sourcePlans: [] as PlanSummary[]
            })
          )
        )
      ),
      catchError(() => of({ farmId: 0, sourcePlans: [] as PlanSummary[] }))
    );
  }

  loadCarryoverPreview(planId: number): Observable<PlanVsActualSummary> {
    return this.planGateway.getPlanVsActualSummary(planId);
  }

  loadLearningSnapshot(planId: number): Observable<PlanVarianceLearningSnapshot | null> {
    return this.planGateway.getVarianceLearning(planId).pipe(
      catchError((err: unknown) => {
        if (err instanceof HttpErrorResponse && err.status === 404) {
          return of(null);
        }
        return of(null);
      })
    );
  }

  importLearning(
    planId: number,
    sourcePlanId: number
  ): Observable<PlanVarianceLearningSnapshot> {
    return this.planGateway.importVarianceLearning(planId, sourcePlanId);
  }
}
