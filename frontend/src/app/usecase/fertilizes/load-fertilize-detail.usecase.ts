import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { LoadFertilizeDetailInputDto } from './load-fertilize-detail.dtos';
import { LoadFertilizeDetailInputPort } from './load-fertilize-detail.input-port';
import {
  LoadFertilizeDetailOutputPort,
  LOAD_FERTILIZE_DETAIL_OUTPUT_PORT
} from './load-fertilize-detail.output-port';
import { FERTILIZE_GATEWAY, FertilizeGateway } from './fertilize-gateway';

@Injectable()
export class LoadFertilizeDetailUseCase implements LoadFertilizeDetailInputPort {
  constructor(
    @Inject(LOAD_FERTILIZE_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadFertilizeDetailOutputPort,
    @Inject(FERTILIZE_GATEWAY) private readonly fertilizeGateway: FertilizeGateway
  ) {}

  execute(dto: LoadFertilizeDetailInputDto): void {
    this.fertilizeGateway.show(dto.fertilizeId).subscribe({
      next: (fertilize) => this.outputPort.present({ fertilize }),
      error: (err: unknown) =>
        this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
