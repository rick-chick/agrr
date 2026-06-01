import { Inject, Injectable } from '@angular/core';
import { LoadPublicPlanFarmsInputDto } from './load-public-plan-farms.dtos';
import { LoadPublicPlanFarmsInputPort } from './load-public-plan-farms.input-port';
import {
  LoadPublicPlanFarmsOutputPort,
  LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT
} from './load-public-plan-farms.output-port';
import { PUBLIC_PLAN_GATEWAY, PublicPlanGateway } from './public-plan-gateway';

@Injectable()
export class LoadPublicPlanFarmsUseCase implements LoadPublicPlanFarmsInputPort {
  constructor(
    @Inject(LOAD_PUBLIC_PLAN_FARMS_OUTPUT_PORT)
    private readonly outputPort: LoadPublicPlanFarmsOutputPort,
    @Inject(PUBLIC_PLAN_GATEWAY) private readonly publicPlanGateway: PublicPlanGateway
  ) {}

  execute(dto: LoadPublicPlanFarmsInputDto): void {
    this.publicPlanGateway.getFarms(dto.region).subscribe({
      next: (farms) => {
        this.outputPort.present({ farms });
      },
      error: (err: Error) => {
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' });
      }
    });
  }
}
