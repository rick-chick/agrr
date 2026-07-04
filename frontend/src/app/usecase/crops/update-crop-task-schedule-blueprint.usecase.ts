import { Inject, Injectable } from '@angular/core';
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
    this.gateway
      .update(dto.cropId, dto.blueprintId, { gdd_trigger: dto.gddTrigger })
      .subscribe({
        next: (blueprint) => this.outputPort.present({ blueprint }),
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
