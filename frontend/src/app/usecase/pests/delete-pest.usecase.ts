import { Inject, Injectable } from '@angular/core';
import { DeletePestInputDto } from './delete-pest.dtos';
import { DeletePestInputPort } from './delete-pest.input-port';
import {
  DeletePestOutputPort,
  DELETE_PEST_OUTPUT_PORT
} from './delete-pest.output-port';
import { PEST_GATEWAY, PestGateway } from './pest-gateway';

@Injectable()
export class DeletePestUseCase implements DeletePestInputPort {
  constructor(
    @Inject(DELETE_PEST_OUTPUT_PORT) private readonly outputPort: DeletePestOutputPort,
    @Inject(PEST_GATEWAY) private readonly pestGateway: PestGateway
  ) {}

  execute(dto: DeletePestInputDto): void {
    this.pestGateway.destroy(dto.pestId).subscribe({
      next: (undo) => {
        this.outputPort.onSuccess({
          deletedPestId: dto.pestId,
          undo,
          refresh: dto.onAfterUndo
        });
        dto.onSuccess?.();
      },
      error: (err: Error & { error?: { error?: string; errors?: string[] } }) =>
        this.outputPort.onError({
          message:
            err?.error?.error ??
            err?.error?.errors?.join(', ') ??
            err?.message ??
            'Unknown error'
        })
    });
  }
}