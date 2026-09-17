import { HttpErrorResponse } from '@angular/common/http';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { BACKEND_WARMUP_I18N } from '../../core/backend-warmup/backend-warmup';
import { LoadPublicPlanResultsUseCase } from './load-public-plan-results.usecase';
import { LoadPublicPlanResultsOutputPort } from './load-public-plan-results.output-port';
import { PlanGateway } from '../plans/plan-gateway';

describe('LoadPublicPlanResultsUseCase', () => {
  let outputPort: LoadPublicPlanResultsOutputPort;
  let gateway: PlanGateway;
  let useCase: LoadPublicPlanResultsUseCase;

  beforeEach(() => {
    outputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };
    gateway = {
      listPlans: vi.fn(),
      fetchPlan: vi.fn(),
      fetchPlanData: vi.fn(),
      getPublicPlanData: vi.fn(),
      getTaskSchedule: vi.fn(),
      getPlanVsActualSummary: () => of({ plan_id: 0, unrecorded_count: 0, categories: [], top_variance_items: [] }),
      getWeatherRescheduleProposals: () => of([]),
      previewWeatherRescheduleProposal: () => of({} as never),
      getVarianceLearning: vi.fn(),
      importVarianceLearning: vi.fn(),
      patchVarianceLearningProposalProgress: vi.fn(),
      reoptimizeVarianceLearning: () => of({ success: true, plan_id: 0, optimization_enqueued: true }),
      regenerateTaskSchedule: vi.fn(),
      createTaskScheduleItem: () => of({} as never),

      updateTaskScheduleItem: () => of({} as never),
      deletePlan: vi.fn()
    };
    useCase = new LoadPublicPlanResultsUseCase(outputPort, gateway);
  });

  it('calls present when getPublicPlanData succeeds', async () => {
    const data = { id: 42 } as never;

    vi.mocked(gateway.getPublicPlanData).mockReturnValue(of(data));

    useCase.execute({ planId: 42 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(gateway.getPublicPlanData).toHaveBeenCalledWith(42);
    expect(outputPort.present).toHaveBeenCalledWith(data);
    expect(outputPort.onError).not.toHaveBeenCalled();
  });

  it('maps HTTP 404 to i18n key on load failure', async () => {
    vi.mocked(gateway.getPublicPlanData).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 404, statusText: 'Not Found' }))
    );

    useCase.execute({ planId: 99 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'common.api_error.not_found'
    });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('maps HTTP 503 to backend warmup i18n key on load failure', async () => {
    vi.mocked(gateway.getPublicPlanData).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 503, statusText: 'Service Unavailable' }))
    );

    useCase.execute({ planId: 99 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({
      message: BACKEND_WARMUP_I18N.database
    });
    expect(outputPort.present).not.toHaveBeenCalled();
  });

  it('maps non-HTTP failures to generic i18n key on load failure', async () => {
    vi.mocked(gateway.getPublicPlanData).mockReturnValue(
      throwError(() => new Error('Network error'))
    );

    useCase.execute({ planId: 99 });

    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'common.api_error.generic'
    });
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
