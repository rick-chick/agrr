import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { UpdateCropUseCase } from './update-crop.usecase';
import { CropGateway } from './crop-gateway';
import { UpdateCropOutputPort } from './update-crop.output-port';

describe('UpdateCropUseCase', () => {
  const baseGateway = (): CropGateway =>
    ({
      list: () => of([]),
      show: () => of({} as never),
      create: () => of({} as never),
      update: vi.fn(() => of({ id: 1 } as never)),
      destroy: () => of({} as never)
    }) as CropGateway;

  it('calls outputPort.onError with joined errors from 422 body.errors array', () => {
    const gateway = baseGateway();
    gateway.update = vi.fn(() =>
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { errors: ['Name is required', 'Region is invalid'] }
          })
      )
    );

    let receivedError: { message: string } | null = null;
    const outputPort: UpdateCropOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new UpdateCropUseCase(outputPort, gateway);
    useCase.execute({
      cropId: 1,
      name: 'Tomato',
      variety: null,
      area_per_unit: 1,
      revenue_per_area: 1,
      region: 'jp',
      groups: []
    });

    expect(receivedError!.message).toBe('Name is required, Region is invalid');
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
    const outputPort: UpdateCropOutputPort = {
      onSuccess: () => {},
      onError: (dto) => {
        receivedError = dto;
      }
    };

    const useCase = new UpdateCropUseCase(outputPort, gateway);
    useCase.execute({
      cropId: 1,
      name: 'Tomato',
      variety: null,
      area_per_unit: 1,
      revenue_per_area: 1,
      region: 'jp',
      groups: []
    });

    expect(receivedError!.message).toBe('common.api_error.generic');
  });
});
