import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { TranslateService } from '@ngx-translate/core';
import { SavePublicPlanUseCase } from './save-public-plan.usecase';
import { PublicPlanGateway, SavePublicPlanResponse } from './public-plan-gateway';
import { SavePublicPlanOutputPort } from './save-public-plan.output-port';

describe('SavePublicPlanUseCase', () => {
  const mockTranslate: TranslateService = {
    instant: vi.fn((key: string) => {
      if (key === 'public_plans.save.success') {
        return 'Plan saved successfully';
      }
      if (key === 'public_plans.save.error') {
        return 'Failed to save plan';
      }
      if (key === 'plans.errors.plan_already_exists_annual') {
        return 'A plan for this farm already exists.';
      }
      if (key === 'common.api_error.unauthorized') {
        return 'Please log in';
      }
      return key;
    })
  } as unknown as TranslateService;

  it('calls outputPort.present with success message when gateway returns success', () => {
    const response: SavePublicPlanResponse = { success: true, cultivation_plan_id: 99 };

    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => of(response))
    };

    let receivedDto: { message: string; plan_reused?: boolean } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: (dto) => {
        receivedDto = dto as { message: string; plan_reused?: boolean };
      },
      onError: () => {}
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.message).toBe('Plan saved successfully');
    expect(receivedDto!.plan_reused).toBe(false);
    expect(gateway.savePlan).toHaveBeenCalledWith(123);
  });

  it('calls outputPort.present with reused message when plan_reused is true', () => {
    const response: SavePublicPlanResponse = {
      success: true,
      cultivation_plan_id: 42,
      plan_reused: true
    };

    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => of(response))
    };

    let receivedDto: { message: string; plan_reused?: boolean; cultivation_plan_id?: number } | null =
      null;
    const outputPort: SavePublicPlanOutputPort = {
      present: (dto) => {
        receivedDto = dto as {
          message: string;
          plan_reused?: boolean;
          cultivation_plan_id?: number;
        };
      },
      onError: () => {}
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedDto!.message).toBe('A plan for this farm already exists.');
    expect(receivedDto!.plan_reused).toBe(true);
    expect(receivedDto!.cultivation_plan_id).toBe(42);
  });

  it('calls outputPort.onError with error message when gateway returns failure', () => {
    const response: SavePublicPlanResponse = { success: false, error: 'Plan already exists' };

    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => of(response))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe('Plan already exists');
  });

  it('calls outputPort.onError with server error from 422 HttpErrorResponse', () => {
    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 422,
              error: { success: false, error: 'Crop limit exceeded' }
            })
        )
      )
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError!.message).toBe('Crop limit exceeded');
  });

  it('calls outputPort.onError with i18n key for 401 HttpErrorResponse without body error', () => {
    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 401,
              statusText: 'Unauthorized'
            })
        )
      )
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError!.message).toBe('Please log in');
  });

  it('calls outputPort.onError when gateway throws error', () => {
    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => throwError(() => new Error('Network error')))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError!.message).toBe('Network error');
  });
});
