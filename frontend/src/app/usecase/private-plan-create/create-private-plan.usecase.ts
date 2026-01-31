import { Inject, Injectable } from '@angular/core';
import { CreatePrivatePlanInputPort } from './create-private-plan.input-port';
import { CreatePrivatePlanOutputPort, CREATE_PRIVATE_PLAN_OUTPUT_PORT } from './create-private-plan.output-port';
import { PRIVATE_PLAN_CREATE_GATEWAY, PrivatePlanCreateGateway } from './private-plan-create-gateway';
import { CreatePrivatePlanInputDto } from './create-private-plan.dtos';

@Injectable()
export class CreatePrivatePlanUseCase implements CreatePrivatePlanInputPort {
  constructor(
    @Inject(CREATE_PRIVATE_PLAN_OUTPUT_PORT) private readonly outputPort: CreatePrivatePlanOutputPort,
    @Inject(PRIVATE_PLAN_CREATE_GATEWAY) private readonly gateway: PrivatePlanCreateGateway
  ) {}

  execute(dto: CreatePrivatePlanInputDto): void {
    this.gateway.createPlan(dto).subscribe({
      next: (response) => this.outputPort.present(response),
      error: (err) => this.outputPort.onError({ message: err.message })
    });
  }
}