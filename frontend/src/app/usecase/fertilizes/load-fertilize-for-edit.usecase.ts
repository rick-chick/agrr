import { Inject, Injectable } from '@angular/core';
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
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
