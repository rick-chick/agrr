import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DryRunCropSetupProposalUseCase } from './dry-run-crop-setup-proposal.usecase';
import { CROP_SETUP_PROPOSAL_GATEWAY } from './crop-setup-proposal-gateway';
import { DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT } from './crop-setup-proposal.ports';

const proposal = {
  stages: [{ name: '育苗', order: 1, thermal_requirement: { required_gdd: '120' } }],
  agricultural_tasks: [],
  task_schedule_blueprints: []
};

describe('DryRunCropSetupProposalUseCase', () => {
  let useCase: DryRunCropSetupProposalUseCase;
  let gateway: { dryRun: ReturnType<typeof vi.fn> };
  let outputPort: {
    onDryRunStarted: ReturnType<typeof vi.fn>;
    onDryRunSuccess: ReturnType<typeof vi.fn>;
    onError: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    gateway = { dryRun: vi.fn() };
    outputPort = {
      onDryRunStarted: vi.fn(),
      onDryRunSuccess: vi.fn(),
      onError: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        DryRunCropSetupProposalUseCase,
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: gateway },
        { provide: DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT, useValue: outputPort }
      ]
    });

    useCase = TestBed.inject(DryRunCropSetupProposalUseCase);
  });

  it('notifies output port on dry_run success', () => {
    const response = { mode: 'dry_run' as const, valid: true, normalized: proposal };
    gateway.dryRun.mockReturnValue(of(response));

    useCase.execute({ cropId: 42, proposal });

    expect(outputPort.onDryRunStarted).toHaveBeenCalled();
    expect(outputPort.onDryRunSuccess).toHaveBeenCalledWith(response);
  });

  it('maps HTTP errors to api error i18n keys', () => {
    gateway.dryRun.mockReturnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'invalid proposal', error_code: 'invalid_proposal' }
          })
      )
    );

    useCase.execute({ cropId: 42, proposal });

    expect(outputPort.onDryRunStarted).toHaveBeenCalled();
    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'common.api_error.generic'
    });
  });
});
