import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearLearnProposalApplicationProgressCache,
  storeLearnPostMasterPayload
} from '../domain/plans/learn-proposal-application-progress';
import { ApiService } from './api.service';
import { LearnHandoffSyncService } from './learn-handoff-sync.service';

describe('LearnHandoffSyncService', () => {
  const patch = vi.fn();

  beforeEach(() => {
    patch.mockReset();
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();

    TestBed.configureTestingModule({
      providers: [
        LearnHandoffSyncService,
        { provide: ApiService, useValue: { patch } }
      ]
    });
  });

  it('PATCHes learn_handoff when stage GDD apply stores post_master payload', () => {
    patch.mockReturnValue(of({ plan_id: 7 }));

    TestBed.inject(LearnHandoffSyncService);
    storeLearnPostMasterPayload(7, {
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Tomato',
      stageId: 2,
      stageName: 'Vegetative',
      appliedRequiredGdd: 150
    });

    expect(patch).toHaveBeenCalledWith('/api/v1/plans/7/variance_learning', {
      learn_handoff: {
        post_master_payload: {
          kind: 'stage_gdd',
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageName: 'Vegetative',
          appliedRequiredGdd: 150
        }
      }
    });
  });

  it('does not throw when learn_handoff PATCH fails (best-effort sync)', () => {
    patch.mockReturnValue(throwError(() => new Error('network')));

    TestBed.inject(LearnHandoffSyncService);

    expect(() =>
      storeLearnPostMasterPayload(7, {
        kind: 'stage_gdd',
        cropId: 1,
        cropName: 'Tomato',
        stageId: 2,
        stageName: 'Vegetative',
        appliedRequiredGdd: 150
      })
    ).not.toThrow();
    expect(patch).toHaveBeenCalled();
  });
});
