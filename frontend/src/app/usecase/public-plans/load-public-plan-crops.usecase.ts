import { Inject, Injectable } from '@angular/core';
import { LoadPublicPlanCropsInputDto } from './load-public-plan-crops.dtos';
import { LoadPublicPlanCropsInputPort } from './load-public-plan-crops.input-port';
import {
  LoadPublicPlanCropsOutputPort,
  LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT
} from './load-public-plan-crops.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';

@Injectable()
export class LoadPublicPlanCropsUseCase implements LoadPublicPlanCropsInputPort {
  constructor(
    @Inject(LOAD_PUBLIC_PLAN_CROPS_OUTPUT_PORT)
    private readonly outputPort: LoadPublicPlanCropsOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway
  ) {}

  execute(dto: LoadPublicPlanCropsInputDto): void {
    this.publicPlanGateway.getCrops(dto.farmId).subscribe({
      next: (crops) => this.outputPort.present({ crops }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
