import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { vi } from 'vitest';
import { Crop } from '../../domain/crops/crop';
import { LoadCropDetailUseCase } from './load-crop-detail.usecase';
import { CropGateway } from './crop-gateway';
import { LoadCropDetailOutputPort } from './load-crop-detail.output-port';

describe('LoadCropDetailUseCase', () => {
  it('maps HTTP 404 to i18n key on gateway failure', () => {
    const crop: Crop = { id: 3, name: 'Tomato', is_reference: false, groups: [] };
    const gateway: CropGateway = {
      list: () => of([]),
      show: () =>
        throwError(() => new HttpErrorResponse({ status: 404, statusText: 'Not Found' })),
      create: () => of(crop),
      update: () => of(crop),
      destroy: () => of(undefined)
    };

    const onError = vi.fn();
    const outputPort: LoadCropDetailOutputPort = {
      present: () => {},
      onError
    };

    const useCase = new LoadCropDetailUseCase(outputPort, gateway);
    useCase.execute({ cropId: 999 });

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.not_found' });
  });

  it('maps HTTP 500 to generic i18n key on gateway failure', () => {
    const crop: Crop = { id: 3, name: 'Tomato', is_reference: false, groups: [] };
    const gateway: CropGateway = {
      list: () => of([]),
      show: () =>
        throwError(() => new HttpErrorResponse({ status: 500, statusText: 'Internal Server Error' })),
      create: () => of(crop),
      update: () => of(crop),
      destroy: () => of(undefined)
    };

    const onError = vi.fn();
    const outputPort: LoadCropDetailOutputPort = {
      present: () => {},
      onError
    };

    const useCase = new LoadCropDetailUseCase(outputPort, gateway);
    useCase.execute({ cropId: 1 });

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
  });
});
