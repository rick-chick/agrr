import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { UpdateFarmUseCase } from './update-farm.usecase';
import { FarmGateway } from './farm-gateway';
import { UpdateFarmOutputPort } from './update-farm.output-port';

describe('UpdateFarmUseCase', () => {
  const baseGateway = (): FarmGateway =>
    ({
      list: () => of([]),
      show: () => of({} as never),
      create: () => of({} as never),
      update: vi.fn(() => of({ id: 1 } as never)),
      destroy: () => of({} as never),
      createField: () => of({} as never),
      updateField: () => of({} as never),
      destroyField: () => of({} as never),
      fetchWeatherData: () => of({} as never),
      listFieldsByFarm: () => of([])
    }) as FarmGateway;

  it('calls outputPort.onError with joined errors from 422 body.errors array', () => {
    const gateway = baseGateway();
    gateway.update = vi.fn(() =>
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { errors: ['Name is required'] }
          })
      )
    );

    let receivedError: { message: string } | null = null;
    const outputPort: UpdateFarmOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new UpdateFarmUseCase(outputPort, gateway);
    useCase.execute({
      farmId: 1,
      name: 'Farm',
      region: 'jp',
      latitude: 35,
      longitude: 139
    });

    expect(receivedError!.message).toBe('Name is required');
  });

  it('calls outputPort.onError with generic key when API returns legacy body.error only', () => {
    const gateway = baseGateway();
    gateway.update = vi.fn(() =>
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'legacy' }
          })
      )
    );

    let receivedError: { message: string } | null = null;
    const outputPort: UpdateFarmOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new UpdateFarmUseCase(outputPort, gateway);
    useCase.execute({
      farmId: 1,
      name: 'Farm',
      region: 'jp',
      latitude: 35,
      longitude: 139
    });

    expect(receivedError!.message).toBe('common.api_error.generic');
  });
});
