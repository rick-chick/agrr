import { Inject, Injectable } from '@angular/core';
import { UpdatePestInputDto } from './update-pest.dtos';
import { UpdatePestInputPort } from './update-pest.input-port';
import {
  UpdatePestOutputPort,
  UPDATE_PEST_OUTPUT_PORT
} from './update-pest.output-port';
import { PEST_GATEWAY, PestGateway } from './pest-gateway';

@Injectable()
export class UpdatePestUseCase implements UpdatePestInputPort {
  constructor(
    @Inject(UPDATE_PEST_OUTPUT_PORT) private readonly outputPort: UpdatePestOutputPort,
    @Inject(PEST_GATEWAY) private readonly pestGateway: PestGateway
  ) {}

  execute(dto: UpdatePestInputDto): void {
    this.pestGateway
      .update(dto.pestId, {
        name: dto.name,
        name_scientific: dto.name_scientific,
        family: dto.family,
        order: dto.order,
        description: dto.description,
        occurrence_season: dto.occurrence_season,
        region: dto.region
      })
      .subscribe({
        next: (pest) => {
          this.outputPort.onSuccess({ pest });
          dto.onSuccess?.(pest);
        },
        error: (err: Error & { error?: { errors?: string[] } }) =>
          this.outputPort.onError({
            message: err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
          })
      });
  }
}