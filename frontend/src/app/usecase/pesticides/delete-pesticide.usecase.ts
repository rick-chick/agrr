import { Inject, Injectable } from '@angular/core';
import { DeletePesticideInputDto } from './delete-pesticide.dtos';
import { DeletePesticideInputPort } from './delete-pesticide.input-port';
import {
  DeletePesticideOutputPort,
  DELETE_PESTICIDE_OUTPUT_PORT
} from './delete-pesticide.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class DeletePesticideUseCase implements DeletePesticideInputPort {
  constructor(
    @Inject(DELETE_PESTICIDE_OUTPUT_PORT) private readonly outputPort: DeletePesticideOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(dto: DeletePesticideInputDto): void {
    this.pesticideGateway.destroy(dto.pesticideId).subscribe({
      next: (undo) => {
        this.outputPort.onSuccess({
          deletedPesticideId: dto.pesticideId,
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