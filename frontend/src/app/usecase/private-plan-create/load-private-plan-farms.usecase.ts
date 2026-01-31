import { Inject, Injectable } from '@angular/core';
import { LoadPrivatePlanFarmsInputPort } from './load-private-plan-farms.input-port';
import { LoadPrivatePlanFarmsOutputPort, LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT } from './load-private-plan-farms.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY, PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { PrivatePlanFarmsDataDto } from './load-private-plan-farms.dtos';

@Injectable()
export class LoadPrivatePlanFarmsUseCase implements LoadPrivatePlanFarmsInputPort {
  constructor(
    @Inject(LOAD_PRIVATE_PLAN_FARMS_OUTPUT_PORT) private readonly outputPort: LoadPrivatePlanFarmsOutputPort,
    @Inject(PRIVATE_PLAN_CREATE_GATEWAY) private readonly gateway: PrivatePlanCreateGateway
  ) {}

  execute(): void {
    this.gateway.fetchFarms().subscribe({
      next: (farms) => this.outputPort.present({ farms }),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}