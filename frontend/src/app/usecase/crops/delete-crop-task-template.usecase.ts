import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_TASK_TEMPLATE_GATEWAY,
  CropTaskTemplateGateway
} from './crop-task-template-gateway';
import {
  DELETE_CROP_TASK_TEMPLATE_OUTPUT_PORT,
  DeleteCropTaskTemplateInputDto,
  DeleteCropTaskTemplateInputPort,
  DeleteCropTaskTemplateOutputPort
} from './crop-task-template.ports';

@Injectable()
export class DeleteCropTaskTemplateUseCase implements DeleteCropTaskTemplateInputPort {
  constructor(
    @Inject(DELETE_CROP_TASK_TEMPLATE_OUTPUT_PORT)
    private readonly outputPort: DeleteCropTaskTemplateOutputPort,
    @Inject(CROP_TASK_TEMPLATE_GATEWAY) private readonly gateway: CropTaskTemplateGateway
  ) {}

  execute(dto: DeleteCropTaskTemplateInputDto): void {
    this.gateway.destroy(dto.cropId, dto.templateId).subscribe({
      next: () => this.outputPort.present({ templateId: dto.templateId }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
