import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  clearLearnReorganizePipelineError,
  setLearnReorganizePipelineError,
  storeLearnReorganizePipelineAutoChainSkipPlacement
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

export interface StartLearnVarianceLearningReoptimizeInputDto {
  planId: number;
  onSuccess?: () => void;
  onError?: (message: string) => void;
}

@Injectable()
export class StartLearnVarianceLearningReoptimizeUseCase {
  constructor(@Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway) {}

  execute(dto: StartLearnVarianceLearningReoptimizeInputDto): void {
    clearLearnReorganizePipelineError(dto.planId);
    storeLearnReorganizePipelineAutoChainSkipPlacement(dto.planId);

    this.planGateway.reoptimizeVarianceLearning(dto.planId).subscribe({
      next: (response) => {
        if (response.optimization_enqueued) {
          dto.onSuccess?.();
          return;
        }
        const message = 'plans.learn.one_click_reoptimize.error.adjust_failed';
        setLearnReorganizePipelineError(dto.planId, message);
        dto.onError?.(message);
      },
      error: (err: unknown) => {
        const message = apiErrorI18nKey(err);
        setLearnReorganizePipelineError(dto.planId, message);
        dto.onError?.(message);
      }
    });
  }
}
