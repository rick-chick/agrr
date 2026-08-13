import { Inject, Injectable } from '@angular/core';
import { catchError, map, Observable, of } from 'rxjs';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

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
}
