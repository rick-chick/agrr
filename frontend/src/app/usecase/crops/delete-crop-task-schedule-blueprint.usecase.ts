import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from './crop-task-schedule-blueprint-gateway';
import {
  DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT,
  DeleteCropTaskScheduleBlueprintInputDto,
  DeleteCropTaskScheduleBlueprintInputPort,
  DeleteCropTaskScheduleBlueprintOutputPort
} from './crop-task-schedule-blueprint.ports';

@Injectable()
export class DeleteCropTaskScheduleBlueprintUseCase implements DeleteCropTaskScheduleBlueprintInputPort {
  constructor(
    @Inject(DELETE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT)
    private readonly outputPort: DeleteCropTaskScheduleBlueprintOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly gateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: DeleteCropTaskScheduleBlueprintInputDto): void {
    this.gateway.destroy(dto.cropId, dto.blueprintId).subscribe({
      next: () => this.outputPort.present({ blueprintId: dto.blueprintId }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
