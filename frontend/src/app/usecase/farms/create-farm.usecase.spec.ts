import { throwError } from 'rxjs';
import { describe, expect, it, vi } from 'vitest';
import { CreateFarmUseCase } from './create-farm.usecase';
import { FarmGateway } from './farm-gateway';
import { CreateFarmOutputPort } from './create-farm.output-port';
import { ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY } from '../../core/i18n/resolve-activerecord-api-error-i18n-key';

describe('CreateFarmUseCase', () => {
  it('maps server farm limit message to activerecord i18n key on error', () => {
    const gateway: FarmGateway = {
      list: () => throwError(() => new Error('unused')),
      show: () => throwError(() => new Error('unused')),
      listFieldsByFarm: () => throwError(() => new Error('unused')),
      create: () =>
        throwError(() => ({
          message: 'Http failure',
          error: { errors: ['作成できるFarmは4件までです'] }
        })),
      update: () => throwError(() => new Error('unused')),
      destroy: () => throwError(() => new Error('unused')),
      createField: () => throwError(() => new Error('unused')),
      updateField: () => throwError(() => new Error('unused')),
      destroyField: () => throwError(() => new Error('unused'))
    };

    const onError = vi.fn();
    const outputPort: CreateFarmOutputPort = {
      onSuccess: () => {},
      onError
    };

    const useCase = new CreateFarmUseCase(outputPort, gateway);
    useCase.execute({
      name: 'Farm',
      region: 'jp',
      latitude: 35.0,
      longitude: 135.0
    });

    expect(onError).toHaveBeenCalledWith({
      message: ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY
    });
  });
});
