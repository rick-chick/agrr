import { Inject, Injectable } from '@angular/core';
import { LoadPesticideListInputPort } from './load-pesticide-list.input-port';
import {
  LoadPesticideListOutputPort,
  LOAD_PESTICIDE_LIST_OUTPUT_PORT
} from './load-pesticide-list.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class LoadPesticideListUseCase implements LoadPesticideListInputPort {
  constructor(
    @Inject(LOAD_PESTICIDE_LIST_OUTPUT_PORT) private readonly outputPort: LoadPesticideListOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(): void {
    this.pesticideGateway.list().subscribe({
      next: (pesticides) => this.outputPort.present({ pesticides }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
