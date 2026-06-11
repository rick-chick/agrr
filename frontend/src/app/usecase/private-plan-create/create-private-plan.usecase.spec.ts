import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { vi } from 'vitest';
import { CreatePrivatePlanUseCase } from './create-private-plan.usecase';
import { CreatePrivatePlanOutputPort } from './create-private-plan.output-port';
import { PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { CreatePrivatePlanInputDto, CreatePrivatePlanResponseDto } from './create-private-plan.dtos';
import { TranslateService } from '@ngx-translate/core';

describe('CreatePrivatePlanUseCase', () => {
  const translate = {
    instant: vi.fn((key: string) => (key === 'plans.errors.no_fields_in_farm' ? '圃場を登録してください' : key))
  } as unknown as TranslateService;

  it('calls outputPort.present with response from gateway', () => {
    const inputDto: CreatePrivatePlanInputDto = {
      farmId: 1,
      planName: 'Test Plan'
    };

    const response: CreatePrivatePlanResponseDto = { id: 123 };

    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarmsForPlanCreate: () => of([]),
      fetchFarm: () => of({} as any),
      fetchCrops: () => of([]),
      createPlan: () => of(response)
    };

    let receivedDto: CreatePrivatePlanResponseDto | null = null;
    const outputPort: CreatePrivatePlanOutputPort = {
      present: (dto) => {
        receivedDto = dto;
      },
      onError: () => {}
    };

    const useCase = new CreatePrivatePlanUseCase(outputPort, gateway, translate);
    useCase.execute(inputDto);

    expect(receivedDto).not.toBeNull();
    expect(receivedDto!.id).toEqual(123);
  });

  it('maps 422 body.error to translated message on onError', () => {
    const gateway: PrivatePlanCreateGateway = {
      fetchFarms: () => of([]),
      fetchFarmsForPlanCreate: () => of([]),
      fetchFarm: () => of({} as any),
      fetchCrops: () => of([]),
      createPlan: () =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 422,
              error: { error: 'plans.errors.no_fields_in_farm' }
            })
        )
    };

    let message = '';
    const outputPort: CreatePrivatePlanOutputPort = {
      present: () => {},
      onError: (dto) => {
        message = dto.message;
      }
    };

    const useCase = new CreatePrivatePlanUseCase(outputPort, gateway, translate);
    useCase.execute({ farmId: 1 });

    expect(message).toBe('圃場を登録してください');
  });
});
