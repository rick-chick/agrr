import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadPlanDetailInputDto } from './load-plan-detail.dtos';
import { LoadPlanDetailInputPort } from './load-plan-detail.input-port';
import {
  LoadPlanDetailOutputPort,
  LOAD_PLAN_DETAIL_OUTPUT_PORT
} from './load-plan-detail.output-port';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class LoadPlanDetailUseCase implements LoadPlanDetailInputPort {
  constructor(
    @Inject(LOAD_PLAN_DETAIL_OUTPUT_PORT) private readonly outputPort: LoadPlanDetailOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadPlanDetailInputDto): void {
    forkJoin({
      plan: this.planGateway.fetchPlan(dto.planId),
      planData: this.planGateway.fetchPlanData(dto.planId)
    }).subscribe({
      next: (data) =>
        this.outputPort.present({
          plan: data.plan,
          planData: data.planData
        }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
