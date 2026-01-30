import { Inject, Injectable } from '@angular/core';
import { LoadFertilizeListInputPort } from './load-fertilize-list.input-port';
import {
  LoadFertilizeListOutputPort,
  LOAD_FERTILIZE_LIST_OUTPUT_PORT
} from './load-fertilize-list.output-port';
import { FERTILIZE_GATEWAY, FertilizeGateway } from './fertilize-gateway';

@Injectable()
export class LoadFertilizeListUseCase implements LoadFertilizeListInputPort {
  constructor(
    @Inject(LOAD_FERTILIZE_LIST_OUTPUT_PORT) private readonly outputPort: LoadFertilizeListOutputPort,
    @Inject(FERTILIZE_GATEWAY) private readonly fertilizeGateway: FertilizeGateway
  ) {}

  execute(): void {
    this.fertilizeGateway.list().subscribe({
      next: (fertilizes) => this.outputPort.present({ fertilizes }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
