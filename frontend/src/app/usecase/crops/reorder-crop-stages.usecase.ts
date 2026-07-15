import { Inject, Injectable } from '@angular/core';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { ReorderCropStagesInputDto } from './reorder-crop-stages.dtos';
import {
  REORDER_CROP_STAGES_OUTPUT_PORT,
  ReorderCropStagesOutputPort
} from './reorder-crop-stages.output-port';

@Injectable()
export class ReorderCropStagesUseCase {
  constructor(
    @Inject(REORDER_CROP_STAGES_OUTPUT_PORT) private readonly outputPort: ReorderCropStagesOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: ReorderCropStagesInputDto): void {
    this.cropStageGateway.reorderCropStages(dto.cropId, dto.orders).subscribe({
      next: (stages) => this.outputPort.present({ stages }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}
