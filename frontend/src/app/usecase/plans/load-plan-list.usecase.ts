import { Inject, Injectable } from '@angular/core';
import { of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import type { PlanListPlan } from '../../domain/plans/plan-list-plan';
import { LoadPlanListInputPort } from './load-plan-list.input-port';
import { LoadPlanListOutputPort, LOAD_PLAN_LIST_OUTPUT_PORT } from './load-plan-list.output-port';
import { loadPlanListInputGapSummaries } from './load-plan-list-input-gap-summaries';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class LoadPlanListUseCase implements LoadPlanListInputPort {
  constructor(
    @Inject(LOAD_PLAN_LIST_OUTPUT_PORT) private readonly outputPort: LoadPlanListOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(): void {
    this.planGateway
      .listPlans()
      .pipe(
        switchMap((plans) => {
          if (plans.length === 0) {
            return of({ plans: [] as PlanListPlan[] });
          }

          return loadPlanListInputGapSummaries(plans, this.planGateway).pipe(
            map((inputGapByPlanId) => ({
              plans: plans.map((plan) => ({
                ...plan,
                inputGap: inputGapByPlanId.get(plan.id) ?? null
              }))
            }))
          );
        })
      )
      .subscribe({
        next: (dto) => this.outputPort.present(dto),
        error: (err: Error) =>
          this.outputPort.onError({
            message: err?.message ?? 'Unknown error',
            scope: 'load-plan-list'
          })
      });
  }
}
