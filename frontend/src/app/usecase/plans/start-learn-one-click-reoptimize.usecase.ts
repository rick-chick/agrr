import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { buildCurrentPlacementAdjustMoves } from '../../domain/plans/learn-reorganize-skip-placement-pipeline';
import {
  clearLearnReorganizePipelineError,
  setLearnReorganizePipelineError,
  storeLearnReorganizePipelineAutoChainSkipPlacement
} from '../../domain/plans/learn-reorganize-pipeline-auto-chain';
import { GANTT_PLAN_GATEWAY, GanttPlanGateway } from './gantt-plan-gateway';

export interface StartLearnOneClickReoptimizeInputDto {
  planId: number;
  onSuccess?: () => void;
  onError?: (message: string) => void;
}

@Injectable()
export class StartLearnOneClickReoptimizeUseCase {
  constructor(@Inject(GANTT_PLAN_GATEWAY) private readonly ganttGateway: GanttPlanGateway) {}

  execute(dto: StartLearnOneClickReoptimizeInputDto): void {
    clearLearnReorganizePipelineError(dto.planId);
    this.ganttGateway.loadPlanData('private', dto.planId).subscribe({
      next: (planData) => {
        const cultivations = planData?.data?.cultivations ?? [];
        if (cultivations.length === 0) {
          dto.onError?.('plans.learn.one_click_reoptimize.error.no_cultivations');
          return;
        }

        const moves = buildCurrentPlacementAdjustMoves(cultivations);
        storeLearnReorganizePipelineAutoChainSkipPlacement(dto.planId);

        this.ganttGateway
          .adjustPlanMoves({
            planType: 'private',
            planId: dto.planId,
            moves
          })
          .subscribe({
            next: (result) => {
              if (result.success === false) {
                const message = result.message ?? 'plans.learn.one_click_reoptimize.error.adjust_failed';
                setLearnReorganizePipelineError(dto.planId, message);
                dto.onError?.(message);
                return;
              }
              dto.onSuccess?.();
            },
            error: (err: unknown) => {
              const message = apiErrorI18nKey(err);
              setLearnReorganizePipelineError(dto.planId, message);
              dto.onError?.(message);
            }
          });
      },
      error: (err: unknown) => dto.onError?.(apiErrorI18nKey(err))
    });
  }
}
