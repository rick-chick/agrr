import { Injectable, inject } from '@angular/core';
import { ApiService } from './api.service';
import { FlashMessageService } from './flash-message.service';
import type { PlanVarianceLearningSnapshot } from '../domain/plans/plan-variance-learning-snapshot';
import { registerLearnOrchestrationProgressPatchHandler } from '../domain/plans/learn-master-update-orchestration';

@Injectable({ providedIn: 'root' })
export class LearnOrchestrationProgressSyncService {
  private readonly flashMessage = inject(FlashMessageService);

  constructor(private readonly apiClient: ApiService) {
    registerLearnOrchestrationProgressPatchHandler((planId, updates) => {
      this.apiClient
        .patch<PlanVarianceLearningSnapshot>(`/api/v1/plans/${planId}/variance_learning`, {
          reorganize_orchestration_progress: updates
        })
        .subscribe({
          error: () => {
            this.flashMessage.show({
              type: 'error',
              text: 'plans.learn.pipeline_status.orchestration_progress_sync_failed'
            });
          }
        });
    });
  }
}
