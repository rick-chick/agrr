import { Inject, Injectable } from '@angular/core';
import { UpdateCropStageInputPort } from './update-crop-stage.input-port';
import { UpdateCropStageOutputPort, UPDATE_CROP_STAGE_OUTPUT_PORT } from './update-crop-stage.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { UpdateCropStageInputDto } from './update-crop-stage.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class UpdateCropStageUseCase implements UpdateCropStageInputPort {
  constructor(
    @Inject(UPDATE_CROP_STAGE_OUTPUT_PORT) private readonly outputPort: UpdateCropStageOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: UpdateCropStageInputDto): void {
    this.cropStageGateway.updateCropStage(dto.cropId, dto.stageId, dto.payload).subscribe({
      next: (stage) => this.outputPort.present({ stage }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}