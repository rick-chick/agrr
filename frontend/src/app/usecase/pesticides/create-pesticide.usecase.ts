import { Inject, Injectable } from '@angular/core';
import { CreatePesticideInputDto } from './create-pesticide.dtos';
import { CreatePesticideInputPort } from './create-pesticide.input-port';
import {
  CreatePesticideOutputPort,
  CREATE_PESTICIDE_OUTPUT_PORT
} from './create-pesticide.output-port';
import { PESTICIDE_GATEWAY, PesticideGateway } from './pesticide-gateway';

@Injectable()
export class CreatePesticideUseCase implements CreatePesticideInputPort {
  constructor(
    @Inject(CREATE_PESTICIDE_OUTPUT_PORT) private readonly outputPort: CreatePesticideOutputPort,
    @Inject(PESTICIDE_GATEWAY) private readonly pesticideGateway: PesticideGateway
  ) {}

  execute(dto: CreatePesticideInputDto): void {
    this.pesticideGateway
      .create({
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