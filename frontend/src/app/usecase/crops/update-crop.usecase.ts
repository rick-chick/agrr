import { Inject, Injectable } from '@angular/core';
import { UpdateCropInputDto } from './update-crop.dtos';
import { UpdateCropInputPort } from './update-crop.input-port';
import {
  UpdateCropOutputPort,
  UPDATE_CROP_OUTPUT_PORT
} from './update-crop.output-port';
import { CROP_GATEWAY, CropGateway } from './crop-gateway';

@Injectable()
export class UpdateCropUseCase implements UpdateCropInputPort {
  constructor(
    @Inject(UPDATE_CROP_OUTPUT_PORT) private readonly outputPort: UpdateCropOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: UpdateCropInputDto): void {
    this.cropGateway
      .update(dto.cropId, {
        name: dto.name,
        variety: dto.variety,
        area_per_unit: dto.area_per_unit,
        revenue_per_area: dto.revenue_per_area,
        region: dto.region,
        groups: dto.groups ?? [],
        ...(dto.is_reference !== undefined && { is_reference: dto.is_reference })
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
