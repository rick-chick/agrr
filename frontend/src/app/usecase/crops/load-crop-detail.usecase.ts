import { Inject, Injectable } from '@angular/core';
import { LoadCropDetailInputDto } from './load-crop-detail.dtos';
import { LoadCropDetailInputPort } from './load-crop-detail.input-port';
import {
  LoadCropDetailOutputPort,
  LOAD_CROP_DETAIL_OUTPUT_PORT
} from './load-crop-detail.output-port';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';

@Injectable()
export class LoadCropDetailUseCase implements LoadCropDetailInputPort {
  constructor(
    @Inject(LOAD_CROP_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadCropDetailOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: LoadCropDetailInputDto): void {
    this.cropGateway.show(dto.cropId).subscribe({
      next: (crop) => this.outputPort.present({ crop }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
