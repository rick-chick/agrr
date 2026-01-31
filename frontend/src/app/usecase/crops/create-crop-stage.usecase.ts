import { Inject, Injectable } from '@angular/core';
import { CreateCropStageInputPort } from './create-crop-stage.input-port';
import { CreateCropStageOutputPort, CREATE_CROP_STAGE_OUTPUT_PORT } from './create-crop-stage.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { CreateCropStageInputDto } from './create-crop-stage.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class CreateCropStageUseCase implements CreateCropStageInputPort {
  constructor(
    @Inject(CREATE_CROP_STAGE_OUTPUT_PORT) private readonly outputPort: CreateCropStageOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: CreateCropStageInputDto): void {
    this.cropStageGateway.createCropStage(dto.cropId, dto.payload).subscribe({
      next: (stage) => this.outputPort.present({ stage }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}