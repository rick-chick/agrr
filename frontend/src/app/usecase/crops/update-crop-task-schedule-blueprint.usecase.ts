import { Inject, Injectable } from '@angular/core';
import { stageNameForOrder } from '../../domain/crops/crop-stage-name';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from './crop-task-schedule-blueprint-gateway';
import {
  UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  UpdateCropTaskScheduleBlueprintInputDto,
  UpdateCropTaskScheduleBlueprintInputPort,
  UpdateCropTaskScheduleBlueprintOutputPort
} from './crop-task-schedule-blueprint.ports';

@Injectable()
export class UpdateCropTaskScheduleBlueprintUseCase implements UpdateCropTaskScheduleBlueprintInputPort {
  constructor(
    @Inject(UPDATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT)
    private readonly outputPort: UpdateCropTaskScheduleBlueprintOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly gateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: UpdateCropTaskScheduleBlueprintInputDto): void {
    this.outputPort.onUpdateStarted(dto.blueprintId);
    const payload: {
      gdd_trigger?: number;
      stage_order?: number | null;
      stage_name?: string | null;
    } = {};
    if (dto.gddTrigger != null && !Number.isNaN(dto.gddTrigger)) {
      payload.gdd_trigger = dto.gddTrigger;
    }
    if (dto.stageOrder !== undefined) {
      payload.stage_order = dto.stageOrder;
      payload.stage_name = stageNameForOrder(dto.cropStages, dto.stageOrder);
    }
    this.gateway
      .update(dto.cropId, dto.blueprintId, payload)
      .subscribe({
        next: (blueprint) => this.outputPort.present({ blueprint }),
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
