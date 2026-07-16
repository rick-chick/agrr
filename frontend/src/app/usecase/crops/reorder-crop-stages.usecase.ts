import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { ReorderCropStagesInputPort } from './reorder-crop-stages.input-port';
import {
  ReorderCropStagesOutputPort,
  REORDER_CROP_STAGES_OUTPUT_PORT
} from './reorder-crop-stages.output-port';
import { CROP_STAGE_GATEWAY, CropStageGateway } from './crop-stage-gateway';
import { ReorderCropStagesInputDto } from './reorder-crop-stages.dtos';

@Injectable()
export class ReorderCropStagesUseCase implements ReorderCropStagesInputPort {
  constructor(
    @Inject(REORDER_CROP_STAGES_OUTPUT_PORT) private readonly outputPort: ReorderCropStagesOutputPort,
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway
  ) {}

  execute(dto: ReorderCropStagesInputDto): void {
    this.cropStageGateway.reorderCropStages(dto.cropId, dto.entries).subscribe({
      next: (stages) => this.outputPort.present({ stages }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
