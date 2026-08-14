import { Injectable, Inject } from '@angular/core';
import { catchError, map, Observable, of, switchMap } from 'rxjs';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import {
  hydrateLearnHandoff,
  hydrateLearnProposalApplicationProgress
} from '../../domain/plans/learn-proposal-application-progress';
import { hydrateLearnOrchestrationProgress } from '../../domain/plans/learn-master-update-orchestration';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class LoadPlanLearnCarryoverUseCase {
  constructor(@Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway) {}

  loadFarmContext(planId: number): Observable<PlanSummary[]> {
    return this.planGateway.fetchPlan(planId).pipe(
      switchMap((plan) =>
        this.planGateway.listPlans().pipe(
          map((plans) =>
            plans.filter(
              (candidate) => candidate.farm_id === plan.farm_id && candidate.id !== planId
            )
          ),
          catchError(() => of([] as PlanSummary[]))
        )
      ),
      catchError(() => of([] as PlanSummary[]))
    );
  }

  loadCarryoverPreview(planId: number): Observable<PlanVsActualSummary> {
    return this.planGateway.getPlanVsActualSummary(planId);
  }

  loadLearningSnapshot(planId: number): Observable<PlanVarianceLearningSnapshot | null> {
    return this.planGateway.getVarianceLearning(planId).pipe(
      map((snapshot) => {
        hydrateLearnProposalApplicationProgress(
          planId,
          snapshot.proposal_application_progress ?? {}
        );
        hydrateLearnOrchestrationProgress(
          planId,
          snapshot.reorganize_orchestration_progress ?? {}
        );
        hydrateLearnHandoff(planId, snapshot.learn_handoff);
        return snapshot;
      }),
      catchError(() => of(null))
    );
  }

  importLearning(
    planId: number,
    sourcePlanId: number
  ): Observable<PlanVarianceLearningSnapshot> {
    return this.planGateway.importVarianceLearning(planId, sourcePlanId).pipe(
      map((snapshot) => {
        hydrateLearnProposalApplicationProgress(
          planId,
          snapshot.proposal_application_progress ?? {}
        );
        hydrateLearnHandoff(planId, snapshot.learn_handoff);
        return snapshot;
      })
    );
  }
}
