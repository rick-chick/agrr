import { Inject, Injectable } from '@angular/core';
import { DeleteCropInputDto } from './delete-crop.dtos';
import { DeleteCropInputPort } from './delete-crop.input-port';
import {
  DeleteCropOutputPort,
  DELETE_CROP_OUTPUT_PORT
} from './delete-crop.output-port';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';

@Injectable()
export class DeleteCropUseCase implements DeleteCropInputPort {
  constructor(
    @Inject(DELETE_CROP_OUTPUT_PORT) private readonly outputPort: DeleteCropOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: DeleteCropInputDto): void {
    this.cropGateway.destroy(dto.cropId).subscribe({
      next: (response) => {
        this.outputPort.onSuccess({
          deletedCropId: dto.cropId,
          undo: response,
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
