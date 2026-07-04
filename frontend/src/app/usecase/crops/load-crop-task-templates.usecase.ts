import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_TEMPLATE_GATEWAY,
  CropTaskTemplateGateway
} from './crop-task-template-gateway';
import {
  LOAD_CROP_TASK_TEMPLATES_OUTPUT_PORT,
  LoadCropTaskTemplatesInputDto,
  LoadCropTaskTemplatesInputPort,
  LoadCropTaskTemplatesOutputPort
} from './crop-task-template.ports';

@Injectable()
export class LoadCropTaskTemplatesUseCase implements LoadCropTaskTemplatesInputPort {
  constructor(
    @Inject(LOAD_CROP_TASK_TEMPLATES_OUTPUT_PORT)
    private readonly outputPort: LoadCropTaskTemplatesOutputPort,
    @Inject(CROP_TASK_TEMPLATE_GATEWAY) private readonly gateway: CropTaskTemplateGateway
  ) {}

  execute(dto: LoadCropTaskTemplatesInputDto): void {
    this.gateway.list(dto.cropId).subscribe({
      next: (templates) => this.outputPort.present({ templates }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
