import { Inject, Injectable } from '@angular/core';
import { LoadCropPesticideListInputDto } from './load-crop-pesticide-list.dtos';
import { LoadCropPesticideListInputPort } from './load-crop-pesticide-list.input-port';
import {
  LOAD_CROP_PESTICIDE_LIST_OUTPUT_PORT,
  LoadCropPesticideListOutputPort
} from './load-crop-pesticide-list.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class LoadCropPesticideListUseCase implements LoadCropPesticideListInputPort {
  constructor(
    @Inject(LOAD_CROP_PESTICIDE_LIST_OUTPUT_PORT)
    private readonly outputPort: LoadCropPesticideListOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(dto: LoadCropPesticideListInputDto): void {
    this.pesticideGateway.listForCrop(dto.cropId).subscribe({
      next: (pesticides) => this.outputPort.present({ pesticides }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
