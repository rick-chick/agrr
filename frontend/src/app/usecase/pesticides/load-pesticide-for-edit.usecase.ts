import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { LoadPesticideForEditInputDto } from './load-pesticide-for-edit.dtos';
import { LoadPesticideForEditInputPort } from './load-pesticide-for-edit.input-port';
import {
  LoadPesticideForEditOutputPort,
  LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT
} from './load-pesticide-for-edit.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class LoadPesticideForEditUseCase implements LoadPesticideForEditInputPort {
  constructor(
    @Inject(LOAD_PESTICIDE_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadPesticideForEditOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(dto: LoadPesticideForEditInputDto): void {
    this.pesticideGateway.show(dto.pesticideId).subscribe({
      next: (pesticide) => this.outputPort.present({ pesticide }),
      error: (err: unknown) =>
        this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}