import { Inject, Injectable } from '@angular/core';
import { apiErrorMessage } from '../../core/api-error-message';
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
      error: (err: unknown) =>
        this.outputPort.onError({
          message: apiErrorMessage(err)
        })
    });
  }
}