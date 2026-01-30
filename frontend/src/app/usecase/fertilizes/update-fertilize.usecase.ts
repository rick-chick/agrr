import { Inject, Injectable } from '@angular/core';
import { UpdateFertilizeInputDto } from './update-fertilize.dtos';
import { UpdateFertilizeInputPort } from './update-fertilize.input-port';
import {
  UpdateFertilizeOutputPort,
  UPDATE_FERTILIZE_OUTPUT_PORT
} from './update-fertilize.output-port';
import { FERTILIZE_GATEWAY, FertilizeGateway } from './fertilize-gateway';

@Injectable()
export class UpdateFertilizeUseCase implements UpdateFertilizeInputPort {
  constructor(
    @Inject(UPDATE_FERTILIZE_OUTPUT_PORT) private readonly outputPort: UpdateFertilizeOutputPort,
    @Inject(FERTILIZE_GATEWAY) private readonly fertilizeGateway: FertilizeGateway
  ) {}

  execute(dto: UpdateFertilizeInputDto): void {
    this.fertilizeGateway
      .update(dto.fertilizeId, {
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
