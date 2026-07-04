import { Inject, Injectable } from '@angular/core';
import { cropBlueprintRegenerateErrorI18nKey } from '../../core/crop-blueprint-regenerate-error-i18n';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from './crop-task-schedule-blueprint-gateway';
import {
  REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT,
  RegenerateCropTaskScheduleBlueprintsInputDto,
  RegenerateCropTaskScheduleBlueprintsInputPort,
  RegenerateCropTaskScheduleBlueprintsOutputPort
} from './crop-task-schedule-blueprint.ports';

@Injectable()
export class RegenerateCropTaskScheduleBlueprintsUseCase
  implements RegenerateCropTaskScheduleBlueprintsInputPort
{
  constructor(
    @Inject(REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT)
    private readonly outputPort: RegenerateCropTaskScheduleBlueprintsOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly gateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: RegenerateCropTaskScheduleBlueprintsInputDto): void {
    this.outputPort.onRegenerateStarted();
    this.gateway.regenerate(dto.cropId).subscribe({
      next: (blueprints) => this.outputPort.present({ blueprints }),
      error: (err: unknown) =>
        this.outputPort.onError({ message: cropBlueprintRegenerateErrorI18nKey(err) })
    });
  }
}
