import { Injectable } from '@angular/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { collectSafeLearnProposals } from '../../domain/plans/classify-safe-learn-proposals';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { ApplyBpTimingProposalFromLearnUseCase } from './apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from './apply-stage-gdd-calibration-from-learn.usecase';

export interface BulkApplySafeLearnProposalsInputDto {
  planId: number;
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>;
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>;
  onProgress?: (progress: { applied: number; total: number }) => void;
  onSuccess?: (result: { appliedCount: number; totalSafeCount: number }) => void;
  onError?: (message: string) => void;
}

@Injectable()
export class BulkApplySafeLearnProposalsUseCase {
  constructor(
    private readonly stageGddApplyUseCase: ApplyStageGddCalibrationFromLearnUseCase,
    private readonly bpTimingApplyUseCase: ApplyBpTimingProposalFromLearnUseCase
  ) {}

  execute(dto: BulkApplySafeLearnProposalsInputDto): void {
    const safe = collectSafeLearnProposals(
      dto.planId,
      dto.stageGddProposals,
      dto.blueprintTimingProposals
    );

    if (safe.totalCount === 0) {
      dto.onSuccess?.({ appliedCount: 0, totalSafeCount: 0 });
      return;
    }

    let applied = 0;
    const remaining: Array<() => void> = [];

    const advance = (): void => {
      applied += 1;
      dto.onProgress?.({ applied, total: safe.totalCount });
      if (remaining.length === 0) {
        dto.onSuccess?.({ appliedCount: applied, totalSafeCount: safe.totalCount });
        return;
      }
      const next = remaining.shift();
      next?.();
    };

    for (const proposal of safe.stageGdd) {
      if (proposal.proposedRequiredGdd == null) {
        continue;
      }
      const proposedRequiredGdd = proposal.proposedRequiredGdd;
      remaining.push(() => {
        this.stageGddApplyUseCase.execute({
          planId: dto.planId,
          cropId: proposal.cropId,
          stageId: proposal.stageId,
          proposedRequiredGdd,
          onSuccess: () => advance(),
          onError: (message) => dto.onError?.(message)
        });
      });
    }

    for (const proposal of safe.bpTiming) {
      remaining.push(() => {
        this.bpTimingApplyUseCase.execute({
          planId: dto.planId,
          cropId: proposal.cropId,
          category: proposal.category,
          proposal: proposal.proposalBody,
          onSuccess: () => advance(),
          onError: (message) => dto.onError?.(message)
        });
      });
    }

    const first = remaining.shift();
    first?.();
  }
}
