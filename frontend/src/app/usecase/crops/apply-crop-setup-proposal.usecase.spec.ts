import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApplyCropSetupProposalUseCase } from './apply-crop-setup-proposal.usecase';
import { CROP_SETUP_PROPOSAL_GATEWAY } from './crop-setup-proposal-gateway';
import { APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT } from './crop-setup-proposal.ports';

const proposal = {
  stages: [{ name: '育苗', order: 1, thermal_requirement: { required_gdd: '120' } }],
  agricultural_tasks: [],
  task_schedule_blueprints: []
};

describe('ApplyCropSetupProposalUseCase', () => {
  let useCase: ApplyCropSetupProposalUseCase;
  let gateway: { apply: ReturnType<typeof vi.fn> };
  let outputPort: {
    onApplyStarted: ReturnType<typeof vi.fn>;
    onApplySuccess: ReturnType<typeof vi.fn>;
    onError: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    gateway = { apply: vi.fn() };
    outputPort = {
      onApplyStarted: vi.fn(),
      onApplySuccess: vi.fn(),
      onError: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        ApplyCropSetupProposalUseCase,
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: gateway },
        { provide: APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT, useValue: outputPort }
      ]
    });

    useCase = TestBed.inject(ApplyCropSetupProposalUseCase);
  });

  it('calls onSuccess callback after apply succeeds', () => {
    const response = {
      mode: 'apply' as const,
      valid: true as const,
      normalized: proposal,
      result: { stage_ids: [1], agricultural_task_ids: [2], blueprint_ids: [3] }
    };
    gateway.apply.mockReturnValue(of(response));
    const onSuccess = vi.fn();

    useCase.execute({ cropId: 42, proposal, onSuccess });

    expect(outputPort.onApplyStarted).toHaveBeenCalled();
    expect(outputPort.onApplySuccess).toHaveBeenCalledWith(response);
    expect(onSuccess).toHaveBeenCalled();
  });

  it('maps HTTP errors to api error i18n keys without invoking onSuccess', () => {
    gateway.apply.mockReturnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'apply failed', error_code: 'apply_failed' }
          })
      )
    );
    const onSuccess = vi.fn();

    useCase.execute({ cropId: 42, proposal, onSuccess });

    expect(outputPort.onApplyStarted).toHaveBeenCalled();
    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'common.api_error.generic'
    });
    expect(onSuccess).not.toHaveBeenCalled();
  });
});
