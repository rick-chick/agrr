import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { ApiService } from './api.service';
import { FlashMessageService } from './flash-message.service';
import { LearnOrchestrationProgressSyncService } from './learn-orchestration-progress-sync.service';
import {
  clearLearnOrchestrationProgressCache,
  patchLearnOrchestrationProgress
} from '../domain/plans/learn-master-update-orchestration';

describe('LearnOrchestrationProgressSyncService', () => {
  const patch = vi.fn();
  const show = vi.fn();

  beforeEach(() => {
    patch.mockReset();
    show.mockReset();
    clearLearnOrchestrationProgressCache();

    TestBed.configureTestingModule({
      providers: [
        LearnOrchestrationProgressSyncService,
        { provide: ApiService, useValue: { patch } },
        { provide: FlashMessageService, useValue: { show } }
      ]
    });
  });

  it('shows flash error when orchestration progress PATCH fails', () => {
    patch.mockReturnValue(throwError(() => new Error('network')));

    TestBed.inject(LearnOrchestrationProgressSyncService);
    patchLearnOrchestrationProgress(5, { placement: true });

    expect(patch).toHaveBeenCalledWith('/api/v1/plans/5/variance_learning', {
      reorganize_orchestration_progress: { placement: true }
    });
    expect(show).toHaveBeenCalledWith({
      type: 'error',
      text: 'plans.learn.pipeline_status.orchestration_progress_sync_failed'
    });
  });

  it('does not show flash error when orchestration progress PATCH succeeds', () => {
    patch.mockReturnValue(of({ plan_id: 5 }));

    TestBed.inject(LearnOrchestrationProgressSyncService);
    patchLearnOrchestrationProgress(5, { regenerate: true });

    expect(show).not.toHaveBeenCalled();
  });
});
