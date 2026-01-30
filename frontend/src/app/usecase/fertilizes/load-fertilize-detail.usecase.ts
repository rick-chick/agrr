import { Inject, Injectable } from '@angular/core';
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
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
