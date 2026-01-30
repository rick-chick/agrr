import { Inject, Injectable } from '@angular/core';
import { CreatePestInputDto } from './create-pest.dtos';
import { CreatePestInputPort } from './create-pest.input-port';
import {
  CreatePestOutputPort,
  CREATE_PEST_OUTPUT_PORT
} from './create-pest.output-port';
import { PEST_GATEWAY, PestGateway } from './pest-gateway';

@Injectable()
export class CreatePestUseCase implements CreatePestInputPort {
  constructor(
    @Inject(CREATE_PEST_OUTPUT_PORT) private readonly outputPort: CreatePestOutputPort,
    @Inject(PEST_GATEWAY) private readonly pestGateway: PestGateway
  ) {}

  execute(dto: CreatePestInputDto): void {
    this.pestGateway
      .create({
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