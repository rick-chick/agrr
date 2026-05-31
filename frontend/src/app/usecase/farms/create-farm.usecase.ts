import { Inject, Injectable } from '@angular/core';
import { CreateFarmInputDto } from './create-farm.dtos';
import { CreateFarmInputPort } from './create-farm.input-port';
import { CreateFarmOutputPort, CREATE_FARM_OUTPUT_PORT } from './create-farm.output-port';
import { resolveActiverecordApiErrorI18nKey } from '../../core/i18n/resolve-activerecord-api-error-i18n-key';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class CreateFarmUseCase implements CreateFarmInputPort {
  constructor(
    @Inject(CREATE_FARM_OUTPUT_PORT) private readonly outputPort: CreateFarmOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: CreateFarmInputDto): void {
    this.farmGateway
      .create({
        name: dto.name,
        region: dto.region,
        latitude: dto.latitude,
        longitude: dto.longitude
      })
      .subscribe({
        next: (farm) => {
          this.outputPort.onSuccess({ farm });
          dto.onSuccess?.(farm);
        },
        error: (err: Error & { error?: { errors?: string[] } }) => {
          const rawMessage =
            err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error';
          this.outputPort.onError({
            message: resolveActiverecordApiErrorI18nKey(rawMessage)
          });
        }
      });
  }
}
