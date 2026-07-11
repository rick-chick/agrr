import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { LoadPublicPlanResultsInputDto } from './load-public-plan-results.dtos';
import { LoadPublicPlanResultsInputPort } from './load-public-plan-results.input-port';
import {
  LoadPublicPlanResultsOutputPort,
  LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT
} from './load-public-plan-results.output-port';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';

@Injectable()
export class LoadPublicPlanResultsUseCase implements LoadPublicPlanResultsInputPort {
  constructor(
    @Inject(LOAD_PUBLIC_PLAN_RESULTS_OUTPUT_PORT)
    private readonly outputPort: LoadPublicPlanResultsOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadPublicPlanResultsInputDto): void {
    this.planGateway.getPublicPlanData(dto.planId).subscribe({
      next: (data) => this.outputPort.present(data),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
