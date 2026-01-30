import { Inject, Injectable } from '@angular/core';
import { LoadPestDetailInputDto } from './load-pest-detail.dtos';
import { LoadPestDetailInputPort } from './load-pest-detail.input-port';
import {
  LoadPestDetailOutputPort,
  LOAD_PEST_DETAIL_OUTPUT_PORT
} from './load-pest-detail.output-port';
import { PEST_GATEWAY, PestGateway } from './pest-gateway';

@Injectable()
export class LoadPestDetailUseCase implements LoadPestDetailInputPort {
  constructor(
    @Inject(LOAD_PEST_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadPestDetailOutputPort,
    @Inject(PEST_GATEWAY) private readonly pestGateway: PestGateway
  ) {}

  execute(dto: LoadPestDetailInputDto): void {
    this.pestGateway.show(dto.pestId).subscribe({
      next: (pest) => this.outputPort.present({ pest }),
      error: (err: Error & { error?: { errors?: string[] } }) =>
        this.outputPort.onError({
          message: err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
        })
    });
  }
}