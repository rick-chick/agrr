import { Inject, Injectable } from '@angular/core';
import { DeleteFarmInputDto } from './delete-farm.dtos';
import { DeleteFarmInputPort } from './delete-farm.input-port';
import { DeleteFarmOutputPort, DELETE_FARM_OUTPUT_PORT } from './delete-farm.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class DeleteFarmUseCase implements DeleteFarmInputPort {
  constructor(
    @Inject(DELETE_FARM_OUTPUT_PORT) private readonly outputPort: DeleteFarmOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: DeleteFarmInputDto): void {
    this.farmGateway.destroy(dto.farmId).subscribe({
      next: () => {
        this.outputPort.onSuccess({ deletedFarmId: dto.farmId });
        dto.onSuccess?.();
      },
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
