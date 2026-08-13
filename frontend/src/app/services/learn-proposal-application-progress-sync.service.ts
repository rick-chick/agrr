import { Injectable } from '@angular/core';
import { ApiService } from '../../services/api.service';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type { LearnProposalApplicationStatus } from '../../domain/plans/learn-proposal-application-progress';
import {
  registerLearnProposalApplicationProgressPatchHandler
} from '../../domain/plans/learn-proposal-application-progress';

@Injectable({ providedIn: 'root' })
export class LearnProposalApplicationProgressSyncService {
  constructor(private readonly apiClient: ApiService) {
    registerLearnProposalApplicationProgressPatchHandler((planId, updates) => {
      this.apiClient
        .patch<PlanVarianceLearningSnapshot>(`/api/v1/plans/${planId}/variance_learning`, {
          proposal_application_progress: updates
        })
        .subscribe({
          error: () => {
            /* best-effort sync; local cache remains until next reload */
          }
        });
    });
  }
}

export type { LearnProposalApplicationStatus };
