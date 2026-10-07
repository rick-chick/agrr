import { Inject, Injectable } from '@angular/core';
import { apiErrorMessage } from '../../core/api-error-message';
import { LoadPestForEditInputDto } from './load-pest-for-edit.dtos';
import { LoadPestForEditInputPort } from './load-pest-for-edit.input-port';
import {
  LoadPestForEditOutputPort,
  LOAD_PEST_FOR_EDIT_OUTPUT_PORT
} from './load-pest-for-edit.output-port';
import { PEST_GATEWAY, PestGateway } from './pest-gateway';

@Injectable()
export class LoadPestForEditUseCase implements LoadPestForEditInputPort {
  constructor(
    @Inject(LOAD_PEST_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadPestForEditOutputPort,
    @Inject(PEST_GATEWAY) private readonly pestGateway: PestGateway
  ) {}

  execute(dto: LoadPestForEditInputDto): void {
    this.pestGateway.show(dto.pestId).subscribe({
      next: (pest) => this.outputPort.present({ pest }),
      error: (err: unknown) =>
        this.outputPort.onError({
          message: apiErrorMessage(err)
        })
    });
  }
}