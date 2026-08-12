import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import type { PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { LoadPlanVsActualSummaryInputDto } from './load-plan-vs-actual-summary.dtos';
import { LoadPlanVsActualSummaryInputPort } from './load-plan-vs-actual-summary.input-port';
import {
  LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT,
  LoadPlanVsActualSummaryOutputPort
} from './load-plan-vs-actual-summary.output-port';

@Injectable()
export class LoadPlanVsActualSummaryUseCase implements LoadPlanVsActualSummaryInputPort {
  constructor(
    @Inject(LOAD_PLAN_VS_ACTUAL_SUMMARY_OUTPUT_PORT)
    private readonly outputPort: LoadPlanVsActualSummaryOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadPlanVsActualSummaryInputDto): void {
    this.planGateway.getPlanVsActualSummary(dto.planId).subscribe({
      next: (summary: PlanVsActualSummary) =>
        this.outputPort.present({ summary, loadGeneration: dto.loadGeneration }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
