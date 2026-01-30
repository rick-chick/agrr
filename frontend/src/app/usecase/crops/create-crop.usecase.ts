import { Inject, Injectable } from '@angular/core';
import { CreateCropInputDto } from './create-crop.dtos';
import { CreateCropInputPort } from './create-crop.input-port';
import {
  CreateCropOutputPort,
  CREATE_CROP_OUTPUT_PORT
} from './create-crop.output-port';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';

@Injectable()
export class CreateCropUseCase implements CreateCropInputPort {
  constructor(
    @Inject(CREATE_CROP_OUTPUT_PORT) private readonly outputPort: CreateCropOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: CreateCropInputDto): void {
    this.cropGateway
      .create({
        name: dto.name,
        variety: dto.variety,
        area_per_unit: dto.area_per_unit,
        revenue_per_area: dto.revenue_per_area,
        region: dto.region,
        groups: dto.groups ?? []
      })
      .subscribe({
        next: (crop) => {
          this.outputPort.onSuccess({ crop });
          dto.onSuccess?.(crop);
        },
        error: (err: Error & { error?: { errors?: string[] } }) =>
          this.outputPort.onError({
            message: err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
          })
      });
  }
}
