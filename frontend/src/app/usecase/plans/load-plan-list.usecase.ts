import { Inject, Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadPlanListInputPort } from './load-plan-list.input-port';
import { LoadPlanListOutputPort, LOAD_PLAN_LIST_OUTPUT_PORT } from './load-plan-list.output-port';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class LoadPlanListUseCase implements LoadPlanListInputPort {
  constructor(
    @Inject(LOAD_PLAN_LIST_OUTPUT_PORT) private readonly outputPort: LoadPlanListOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(): void {
    this.planGateway.listPlans().subscribe({
      next: (plans) => this.outputPort.present({ plans }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
