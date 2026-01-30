import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { LoadFarmDetailInputDto } from './load-farm-detail.dtos';
import { LoadFarmDetailInputPort } from './load-farm-detail.input-port';
import {
  LoadFarmDetailOutputPort,
  LOAD_FARM_DETAIL_OUTPUT_PORT
} from './load-farm-detail.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class LoadFarmDetailUseCase implements LoadFarmDetailInputPort {
  constructor(
    @Inject(LOAD_FARM_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadFarmDetailOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(dto: LoadFarmDetailInputDto): void {
    forkJoin({
      farm: this.farmGateway.show(dto.farmId),
      fields: this.farmGateway.listFieldsByFarm(dto.farmId)
    }).subscribe({
      next: (data) =>
        this.outputPort.present({
          farm: data.farm,
          fields: data.fields
        }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
