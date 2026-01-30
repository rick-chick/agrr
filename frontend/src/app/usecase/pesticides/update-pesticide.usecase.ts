import { Inject, Injectable } from '@angular/core';
import { UpdatePesticideInputDto } from './update-pesticide.dtos';
import { UpdatePesticideInputPort } from './update-pesticide.input-port';
import {
  UpdatePesticideOutputPort,
  UPDATE_PESTICIDE_OUTPUT_PORT
} from './update-pesticide.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class UpdatePesticideUseCase implements UpdatePesticideInputPort {
  constructor(
    @Inject(UPDATE_PESTICIDE_OUTPUT_PORT) private readonly outputPort: UpdatePesticideOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(dto: UpdatePesticideInputDto): void {
    this.pesticideGateway
      .update(dto.pesticideId, {
        name: dto.name,
        active_ingredient: dto.active_ingredient,
        description: dto.description,
        crop_id: dto.crop_id,
        pest_id: dto.pest_id,
        region: dto.region
      })
      .subscribe({
        next: (pesticide) => {
          this.outputPort.onSuccess({ pesticide });
          dto.onSuccess?.(pesticide);
        },
        error: (err: Error & { error?: { errors?: string[] } }) =>
          this.outputPort.onError({
            message: err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
          })
      });
  }
}