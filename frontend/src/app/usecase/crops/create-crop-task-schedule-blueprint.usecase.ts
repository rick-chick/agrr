import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from './crop-task-schedule-blueprint-gateway';
import {
  CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  CreateCropTaskScheduleBlueprintInputDto,
  CreateCropTaskScheduleBlueprintInputPort,
  CreateCropTaskScheduleBlueprintOutputPort
} from './crop-task-schedule-blueprint.ports';

@Injectable()
export class CreateCropTaskScheduleBlueprintUseCase implements CreateCropTaskScheduleBlueprintInputPort {
  constructor(
    @Inject(CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT)
    private readonly outputPort: CreateCropTaskScheduleBlueprintOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY) private readonly gateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: CreateCropTaskScheduleBlueprintInputDto): void {
    this.gateway
      .create(dto.cropId, {
        agricultural_task_id: dto.agriculturalTaskId,
        stage_order: dto.stageOrder,
        stage_name: dto.stageName,
        gdd_trigger: dto.gddTrigger
      })
      .subscribe({
        next: (blueprint) => this.outputPort.present({ blueprint }),
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
