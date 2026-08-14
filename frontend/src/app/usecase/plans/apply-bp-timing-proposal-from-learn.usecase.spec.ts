import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  bpTimingProposalProgressKey,
  clearLearnProposalApplicationProgressCache,
  resolveLearnProposalApplicationStatus
} from '../../domain/plans/learn-proposal-application-progress';
import { CROP_SETUP_PROPOSAL_GATEWAY } from '../crops/crop-setup-proposal-gateway';
import { ApplyBpTimingProposalFromLearnUseCase } from './apply-bp-timing-proposal-from-learn.usecase';

const proposalBody = {
  intent: 'blueprint_timing_patch',
  stages: [],
  agricultural_tasks: [],
  task_schedule_blueprints: [{ category: 'general', gdd_trigger: 100 }]
};

describe('ApplyBpTimingProposalFromLearnUseCase', () => {
  const PLAN_ID = 7;
  let useCase: ApplyBpTimingProposalFromLearnUseCase;
  let gateway: { apply: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    gateway = {
      apply: vi.fn(() =>
        of({
          mode: 'apply',
          valid: true,
          normalized: proposalBody,
          result: { stage_ids: [], agricultural_task_ids: [], blueprint_ids: [1] }
        })
      )
    };

    TestBed.configureTestingModule({
      providers: [
        ApplyBpTimingProposalFromLearnUseCase,
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: gateway }
      ]
    });
    useCase = TestBed.inject(ApplyBpTimingProposalFromLearnUseCase);
  });

  it('applies setup_proposal and marks proposal confirmed on success', () => {
    const onSuccess = vi.fn();
    const onError = vi.fn();
    useCase.execute({
      planId: PLAN_ID,
      cropId: 1,
      category: 'general',
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(gateway.apply).toHaveBeenCalledWith(1, proposalBody);
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, bpTimingProposalProgressKey(1, 'general'))
    ).toBe('confirmed');
    expect(onSuccess).toHaveBeenCalled();
    expect(onError).not.toHaveBeenCalled();
  });

  it('notifies onError when apply response is invalid', () => {
    gateway.apply.mockReturnValue(
      of({
        mode: 'apply',
        valid: false,
        errors: [{ path: 'task_schedule_blueprints', message: 'invalid' }]
      })
    );
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      planId: PLAN_ID,
      cropId: 1,
      category: 'general',
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(onError).toHaveBeenCalled();
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('notifies onError when gateway fails', () => {
    gateway.apply.mockReturnValue(throwError(() => new Error('network')));
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      planId: PLAN_ID,
      cropId: 1,
      category: 'general',
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(onError).toHaveBeenCalled();
    expect(onSuccess).not.toHaveBeenCalled();
  });
});
