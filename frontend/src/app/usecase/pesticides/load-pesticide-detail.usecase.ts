import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { LoadPesticideDetailInputDto } from './load-pesticide-detail.dtos';
import { LoadPesticideDetailInputPort } from './load-pesticide-detail.input-port';
import {
  LoadPesticideDetailOutputPort,
  LOAD_PESTICIDE_DETAIL_OUTPUT_PORT
} from './load-pesticide-detail.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class LoadPesticideDetailUseCase implements LoadPesticideDetailInputPort {
  constructor(
    @Inject(LOAD_PESTICIDE_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadPesticideDetailOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(dto: LoadPesticideDetailInputDto): void {
    this.pesticideGateway.show(dto.pesticideId).subscribe({
      next: (pesticide) => this.outputPort.present({ pesticide }),
      error: (err: unknown) =>
        this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}