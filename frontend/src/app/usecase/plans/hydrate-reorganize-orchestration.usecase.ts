import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import { LoadPlanLearnCarryoverUseCase } from './load-plan-learn-carryover.usecase';

@Injectable()
export class HydrateReorganizeOrchestrationUseCase {
  constructor(private readonly carryoverUseCase: LoadPlanLearnCarryoverUseCase) {}

  execute(planId: number): Observable<PlanVarianceLearningSnapshot | null> {
    return this.carryoverUseCase.loadLearningSnapshot(planId);
  }
}
