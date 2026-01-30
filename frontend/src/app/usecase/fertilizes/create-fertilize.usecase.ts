import { Inject, Injectable } from '@angular/core';
import { CreateFertilizeInputDto } from './create-fertilize.dtos';
import { CreateFertilizeInputPort } from './create-fertilize.input-port';
import {
  CreateFertilizeOutputPort,
  CREATE_FERTILIZE_OUTPUT_PORT
} from './create-fertilize.output-port';
import { FERTILIZE_GATEWAY, FertilizeGateway } from './fertilize-gateway';

@Injectable()
export class CreateFertilizeUseCase implements CreateFertilizeInputPort {
  constructor(
    @Inject(CREATE_FERTILIZE_OUTPUT_PORT) private readonly outputPort: CreateFertilizeOutputPort,
    @Inject(FERTILIZE_GATEWAY) private readonly fertilizeGateway: FertilizeGateway
  ) {}

  execute(dto: CreateFertilizeInputDto): void {
    this.fertilizeGateway
      .create({
        name: dto.name,
        n: dto.n,
        p: dto.p,
        k: dto.k,
        description: dto.description,
        package_size: dto.package_size,
        region: dto.region
      })
      .subscribe({
        next: (fertilize) => {
          this.outputPort.onSuccess({ fertilize });
          dto.onSuccess?.(fertilize);
        },
        error: (err: Error & { error?: { errors?: string[] } }) =>
          this.outputPort.onError({
            message: err.error?.errors?.join(', ') ?? err?.message ?? 'Unknown error'
          })
      });
  }
}
