import { Inject, Injectable } from '@angular/core';
import { catchError, map, Observable, of } from 'rxjs';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

export interface PlanNewCarryoverPreset {
  farmId: number;
  sourcePlan: PlanSummary;
}

@Injectable()
export class LoadPlanNewCarryoverUseCase {
  constructor(@Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway) {}

  loadSourcePlans(farmId: number): Observable<PlanSummary[]> {
    return this.planGateway.listPlans().pipe(
      map((plans) => plans.filter((plan) => plan.farm_id === farmId)),
      catchError(() => of([]))
    );
  }

  loadCarryoverPreview(planId: number): Observable<PlanVsActualSummary> {
    return this.planGateway.getPlanVsActualSummary(planId);
  }

  resolveCarryoverPreset(sourcePlanId: number): Observable<PlanNewCarryoverPreset | null> {
    return this.planGateway.fetchPlan(sourcePlanId).pipe(
      map((sourcePlan) => ({ farmId: sourcePlan.farm_id, sourcePlan })),
      catchError(() => of(null))
    );
  }
}
