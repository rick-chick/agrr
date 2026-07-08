import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from './crop-task-schedule-blueprint-gateway';
import {
  LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
  LoadCropTaskScheduleBlueprintsInputDto,
  LoadCropTaskScheduleBlueprintsInputPort,
  LoadCropTaskScheduleBlueprintsOutputPort
} from './crop-task-schedule-blueprint.ports';

@Injectable()
export class LoadCropTaskScheduleBlueprintsUseCase implements LoadCropTaskScheduleBlueprintsInputPort {
  constructor(
    @Inject(LOAD_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT)
    private readonly outputPort: LoadCropTaskScheduleBlueprintsOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly gateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: LoadCropTaskScheduleBlueprintsInputDto): void {
    this.gateway.list(dto.cropId).subscribe({
      next: (blueprints) => this.outputPort.present({ blueprints }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
