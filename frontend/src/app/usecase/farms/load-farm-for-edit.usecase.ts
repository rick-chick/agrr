import { Inject, Injectable } from '@angular/core';
import { LoadFarmForEditInputDto } from './load-farm-for-edit.dtos';
import { LoadFarmForEditInputPort } from './load-farm-for-edit.input-port';
import {
  LoadFarmForEditOutputPort,
  LOAD_FARM_FOR_EDIT_OUTPUT_PORT
} from './load-farm-for-edit.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class LoadFarmForEditUseCase implements LoadFarmForEditInputPort {
  constructor(
    @Inject(LOAD_FARM_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadFarmForEditOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: LoadFarmForEditInputDto): void {
    this.farmGateway.show(dto.farmId).subscribe({
      next: (farm) => this.outputPort.present({ farm }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
