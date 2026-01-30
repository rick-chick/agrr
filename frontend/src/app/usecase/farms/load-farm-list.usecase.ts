import { Inject, Injectable } from '@angular/core';
import { LoadFarmListInputPort } from './load-farm-list.input-port';
import { LoadFarmListOutputPort, LOAD_FARM_LIST_OUTPUT_PORT } from './load-farm-list.output-port';
import { FARM_GATEWAY, FarmGateway } from './farm-gateway';

@Injectable()
export class LoadFarmListUseCase implements LoadFarmListInputPort {
  constructor(
    @Inject(LOAD_FARM_LIST_OUTPUT_PORT) private readonly outputPort: LoadFarmListOutputPort,
    @Inject(FARM_GATEWAY) private readonly farmGateway: FarmGateway
  ) {}

  execute(): void {
    this.farmGateway.list().subscribe({
      next: (farms) => this.outputPort.present({ farms }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
