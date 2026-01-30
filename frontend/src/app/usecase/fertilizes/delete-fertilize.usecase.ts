import { Inject, Injectable } from '@angular/core';
import { DeleteFertilizeInputDto } from './delete-fertilize.dtos';
import { DeleteFertilizeInputPort } from './delete-fertilize.input-port';
import {
  DeleteFertilizeOutputPort,
  DELETE_FERTILIZE_OUTPUT_PORT
} from './delete-fertilize.output-port';
import { FERTILIZE_GATEWAY, FertilizeGateway } from './fertilize-gateway';

@Injectable()
export class DeleteFertilizeUseCase implements DeleteFertilizeInputPort {
  constructor(
    @Inject(DELETE_FERTILIZE_OUTPUT_PORT) private readonly outputPort: DeleteFertilizeOutputPort,
    @Inject(FERTILIZE_GATEWAY) private readonly fertilizeGateway: FertilizeGateway
  ) {}

  execute(dto: DeleteFertilizeInputDto): void {
    this.fertilizeGateway.destroy(dto.fertilizeId).subscribe({
      next: (response) =>
        this.outputPort.onSuccess({
          deletedFertilizeId: dto.fertilizeId,
          undo: response,
          refresh: dto.onAfterUndo
        }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
