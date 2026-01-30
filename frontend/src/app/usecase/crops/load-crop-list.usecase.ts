import { Inject, Injectable } from '@angular/core';
import { LoadCropListInputPort } from './load-crop-list.input-port';
import { LoadCropListOutputPort, LOAD_CROP_LIST_OUTPUT_PORT } from './load-crop-list.output-port';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';

@Injectable()
export class LoadCropListUseCase implements LoadCropListInputPort {
  constructor(
    @Inject(LOAD_CROP_LIST_OUTPUT_PORT) private readonly outputPort: LoadCropListOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(): void {
    this.cropGateway.list().subscribe({
      next: (crops) => this.outputPort.present({ crops }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
