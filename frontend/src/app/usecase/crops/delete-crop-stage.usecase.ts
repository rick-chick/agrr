import { Inject, Injectable } from '@angular/core';
import { DeleteCropStageInputPort } from './delete-crop-stage.input-port';
import { DeleteCropStageOutputPort, DELETE_CROP_STAGE_OUTPUT_PORT } from './delete-crop-stage.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { DeleteCropStageInputDto } from './delete-crop-stage.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class DeleteCropStageUseCase implements DeleteCropStageInputPort {
  constructor(
    @Inject(DELETE_CROP_STAGE_OUTPUT_PORT) private readonly outputPort: DeleteCropStageOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: DeleteCropStageInputDto): void {
    this.cropStageGateway.deleteCropStage(dto.cropId, dto.stageId).subscribe({
      next: () => this.outputPort.present({ success: true }),
      error: (err) => this.outputPort.onError(new ErrorDto(err.message))
    });
  }
}