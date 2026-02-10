import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { TranslateService } from '@ngx-translate/core';
import { SavePublicPlanUseCase } from './save-public-plan.usecase';
import { PublicPlanGateway, SavePublicPlanResponse } from './public-plan-gateway';
import { SavePublicPlanOutputPort } from './save-public-plan.output-port';
import { SavePublicPlanInputDto } from './save-public-plan.dtos';

describe('SavePublicPlanUseCase', () => {
  const mockTranslate: TranslateService = {
    instant: vi.fn((key: string) => {
      if (key === 'public_plans.plan_saved_successfully') {
        return 'Plan saved successfully';
      }
      if (key === 'public_plans.failed_to_save_plan') {
        return 'Failed to save plan';
      }
      return key;
    })
  } as unknown as TranslateService;
  it('calls outputPort.present with success message when gateway returns success', () => {
    const response: SavePublicPlanResponse = { success: true };

    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getFarmSizes: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => of(response))
    };

    let receivedDto: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: (dto) => { receivedDto = dto; },
      onError: () => {}
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.message).toBe('Plan saved successfully');
    expect(gateway.savePlan).toHaveBeenCalledWith(123);
  });

  it('calls outputPort.onError with error message when gateway returns failure', () => {
    const response: SavePublicPlanResponse = { success: false, error: 'Plan already exists' };

    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getFarmSizes: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => of(response))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => { receivedError = dto; }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe('Plan already exists');
    expect(gateway.savePlan).toHaveBeenCalledWith(123);
  });

  it('calls outputPort.onError with default error message when gateway returns failure without error', () => {
    const response: SavePublicPlanResponse = { success: false };

    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getFarmSizes: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => of(response))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => { receivedError = dto; }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe('Failed to save plan');
    expect(gateway.savePlan).toHaveBeenCalledWith(123);
  });

  it('calls outputPort.onError when gateway throws error', () => {
    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getFarmSizes: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => throwError(() => new Error('Network error')))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => { receivedError = dto; }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe('Network error');
    expect(gateway.savePlan).toHaveBeenCalledWith(123);
  });

  it('calls outputPort.onError with default message when gateway throws error without message', () => {
    const gateway: PublicPlanGateway = {
      getFarms: vi.fn(() => of([])),
      getFarmSizes: vi.fn(() => of([])),
      getCrops: vi.fn(() => of([])),
      createPlan: vi.fn(() => of({ plan_id: 0 })),
      savePlan: vi.fn(() => throwError(() => new Error('')))
    };

    let receivedError: { message: string } | null = null;
    const outputPort: SavePublicPlanOutputPort = {
      present: () => {},
      onError: (dto) => { receivedError = dto; }
    };

    const useCase = new SavePublicPlanUseCase(outputPort, gateway, mockTranslate);
    useCase.execute({ planId: 123 });

    expect(receivedError).not.toBeNull();
    expect(receivedError!.message).toBe('Failed to save plan');
    expect(gateway.savePlan).toHaveBeenCalledWith(123);
  });
});