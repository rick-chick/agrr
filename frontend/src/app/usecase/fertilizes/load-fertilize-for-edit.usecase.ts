import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { LoadFertilizeForEditInputDto } from './load-fertilize-for-edit.dtos';
import { LoadFertilizeForEditInputPort } from './load-fertilize-for-edit.input-port';
import {
  LoadFertilizeForEditOutputPort,
  LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT
} from './load-fertilize-for-edit.output-port';
import { FERTILIZE_GATEWAY, FertilizeGateway } from './fertilize-gateway';

@Injectable()
export class LoadFertilizeForEditUseCase implements LoadFertilizeForEditInputPort {
  constructor(
    @Inject(LOAD_FERTILIZE_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadFertilizeForEditOutputPort,
    @Inject(FERTILIZE_GATEWAY) private readonly fertilizeGateway: FertilizeGateway
  ) {}

  execute(dto: LoadFertilizeForEditInputDto): void {
    this.fertilizeGateway.show(dto.fertilizeId).subscribe({
      next: (fertilize) => this.outputPort.present({ fertilize }),
      error: (err: unknown) =>
        this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
