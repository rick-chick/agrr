import { Injectable } from '@angular/core';
import { ApiService } from './api.service';
import type { PlanVarianceLearningSnapshot } from '../domain/plans/plan-variance-learning-snapshot';
import type { LearnHandoffPatch } from '../domain/plans/learn-proposal-application-progress';
import { registerLearnHandoffPatchHandler } from '../domain/plans/learn-proposal-application-progress';

@Injectable({ providedIn: 'root' })
export class LearnHandoffSyncService {
  constructor(private readonly apiClient: ApiService) {
    registerLearnHandoffPatchHandler((planId, patch) => {
      this.apiClient
        .patch<PlanVarianceLearningSnapshot>(`/api/v1/plans/${planId}/variance_learning`, {
          learn_handoff: patch
        })
        .subscribe({
          error: () => {
            /* best-effort sync; local cache remains until next reload */
          }
        });
    });
  }
}

export type { LearnHandoffPatch };
