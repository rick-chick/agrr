import { Inject, Injectable } from '@angular/core';
import { LoadPestListInputPort } from './load-pest-list.input-port';
import { LoadPestListOutputPort, LOAD_PEST_LIST_OUTPUT_PORT } from './load-pest-list.output-port';
import { PEST_GATEWAY, PestGateway } from './pest-gateway';

@Injectable()
export class LoadPestListUseCase implements LoadPestListInputPort {
  constructor(
    @Inject(LOAD_PEST_LIST_OUTPUT_PORT) private readonly outputPort: LoadPestListOutputPort,
    @Inject(PEST_GATEWAY) private readonly pestGateway: PestGateway
  ) {}

  execute(): void {
    this.pestGateway.list().subscribe({
      next: (pests) => this.outputPort.present({ pests }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
