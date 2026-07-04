import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_TEMPLATE_GATEWAY,
  CropTaskTemplateGateway
} from './crop-task-template-gateway';
import {
  CREATE_CROP_TASK_TEMPLATE_OUTPUT_PORT,
  CreateCropTaskTemplateInputDto,
  CreateCropTaskTemplateInputPort,
  CreateCropTaskTemplateOutputPort
} from './crop-task-template.ports';

@Injectable()
export class CreateCropTaskTemplateUseCase implements CreateCropTaskTemplateInputPort {
  constructor(
    @Inject(CREATE_CROP_TASK_TEMPLATE_OUTPUT_PORT)
    private readonly outputPort: CreateCropTaskTemplateOutputPort,
    @Inject(CROP_TASK_TEMPLATE_GATEWAY) private readonly gateway: CropTaskTemplateGateway
  ) {}

  execute(dto: CreateCropTaskTemplateInputDto): void {
    this.gateway
      .create(dto.cropId, { agricultural_task_id: dto.agriculturalTaskId })
      .subscribe({
        next: (template) => this.outputPort.present({ template }),
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
