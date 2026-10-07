import { Inject, Injectable } from '@angular/core';
import { LoadCropForEditInputDto } from './load-crop-for-edit.dtos';
import { LoadCropForEditInputPort } from './load-crop-for-edit.input-port';
import {
  LoadCropForEditOutputPort,
  LOAD_CROP_FOR_EDIT_OUTPUT_PORT
} from './load-crop-for-edit.output-port';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';

@Injectable()
export class LoadCropForEditUseCase implements LoadCropForEditInputPort {
  constructor(
    @Inject(LOAD_CROP_FOR_EDIT_OUTPUT_PORT) private readonly outputPort: LoadCropForEditOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: LoadCropForEditInputDto): void {
    this.cropGateway.show(dto.cropId).subscribe({
      next: (crop) => this.outputPort.present({ crop }),
      error: (err: unknown) =>
        this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
