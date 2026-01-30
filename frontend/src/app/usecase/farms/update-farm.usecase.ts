import { Inject, Injectable } from '@angular/core';
import { UpdateFarmInputDto } from './update-farm.dtos';
import { UpdateFarmInputPort } from './update-farm.input-port';
import { UpdateFarmOutputPort, UPDATE_FARM_OUTPUT_PORT } from './update-farm.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class UpdateFarmUseCase implements UpdateFarmInputPort {
  constructor(
    @Inject(UPDATE_FARM_OUTPUT_PORT) private readonly outputPort: UpdateFarmOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: UpdateFarmInputDto): void {
    this.farmGateway
      .update(dto.farmId, {
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
        error: (err: Error & { error?: { errors?: string[] } }) =>
          this.outputPort.onError({
            message:
              err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
          })
      });
  }
}
