import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { filterVarianceActionItemsOnGantt } from '../../domain/plans/filter-variance-action-items';
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
      planData: this.planGateway.fetchPlanData(dto.planId),
      varianceSummary: this.planGateway.getPlanVsActualSummary(dto.planId).pipe(
        catchError(() => of(null))
      )
    }).subscribe({
      next: (data) => {
        const cultivations = data.planData.data.cultivations ?? [];
        const varianceActionItemsOnGantt = data.varianceSummary
          ? filterVarianceActionItemsOnGantt(
              data.varianceSummary.action_required_items ?? [],
              cultivations
            )
          : [];
        this.outputPort.present({
          plan: data.plan,
          planData: data.planData,
          varianceActionItemsOnGantt
        });
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
