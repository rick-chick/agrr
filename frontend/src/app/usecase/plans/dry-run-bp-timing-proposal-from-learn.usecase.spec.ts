import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CROP_SETUP_PROPOSAL_GATEWAY } from '../crops/crop-setup-proposal-gateway';
import { DryRunBpTimingProposalFromLearnUseCase } from './dry-run-bp-timing-proposal-from-learn.usecase';

const proposalBody = {
  intent: 'blueprint_timing_patch',
  stages: [],
  agricultural_tasks: [],
  task_schedule_blueprints: [{ category: 'general', gdd_trigger: 100 }]
};

describe('DryRunBpTimingProposalFromLearnUseCase', () => {
  let useCase: DryRunBpTimingProposalFromLearnUseCase;
  let gateway: { dryRun: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    gateway = {
      dryRun: vi.fn(() =>
        of({
          mode: 'dry_run',
          valid: true,
          normalized: proposalBody
        })
      )
    };

    TestBed.configureTestingModule({
      providers: [
        DryRunBpTimingProposalFromLearnUseCase,
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: gateway }
      ]
    });
    useCase = TestBed.inject(DryRunBpTimingProposalFromLearnUseCase);
  });

  it('returns formatted JSON preview on successful dry run', () => {
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      cropId: 1,
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(gateway.dryRun).toHaveBeenCalledWith(1, proposalBody);
    expect(onSuccess).toHaveBeenCalledWith(JSON.stringify(proposalBody, null, 2));
    expect(onError).not.toHaveBeenCalled();
  });

  it('notifies onError when dry run response is invalid', () => {
    gateway.dryRun.mockReturnValue(
      of({
        mode: 'dry_run',
        valid: false,
        errors: [{ path: 'task_schedule_blueprints', message: 'invalid' }]
      })
    );
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      cropId: 1,
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(onError).toHaveBeenCalledWith('crops.setup_proposal_import.apply_failed');
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('notifies onError when normalized payload is missing', () => {
    gateway.dryRun.mockReturnValue(
      of({
        mode: 'dry_run',
        valid: true,
        normalized: null
      })
    );
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      cropId: 1,
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(onError).toHaveBeenCalledWith('crops.setup_proposal_import.apply_failed');
    expect(onSuccess).not.toHaveBeenCalled();
  });

  it('notifies onError when gateway fails', () => {
    gateway.dryRun.mockReturnValue(throwError(() => new Error('network')));
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      cropId: 1,
      proposal: proposalBody,
      onSuccess,
      onError
    });

    expect(onError).toHaveBeenCalled();
    expect(onSuccess).not.toHaveBeenCalled();
  });
});
