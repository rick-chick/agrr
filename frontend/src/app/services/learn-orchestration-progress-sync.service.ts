import { Injectable } from '@angular/core';
import { ApiService } from './api.service';
import type { PlanVarianceLearningSnapshot } from '../domain/plans/plan-variance-learning-snapshot';
import type { ReorganizeOrchestrationProgress } from '../domain/plans/learn-master-update-orchestration';
import { registerLearnOrchestrationProgressPatchHandler } from '../domain/plans/learn-master-update-orchestration';

@Injectable({ providedIn: 'root' })
export class LearnOrchestrationProgressSyncService {
  constructor(private readonly apiClient: ApiService) {
    registerLearnOrchestrationProgressPatchHandler((planId, updates) => {
      this.apiClient
        .patch<PlanVarianceLearningSnapshot>(`/api/v1/plans/${planId}/variance_learning`, {
          reorganize_orchestration_progress: updates
        })
        .subscribe({
          error: () => {
            /* best-effort sync; local cache remains until next reload */
          }
        });
    });
  }
}

export type { ReorganizeOrchestrationProgress };
