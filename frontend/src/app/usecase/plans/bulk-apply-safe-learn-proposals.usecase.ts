import { Injectable } from '@angular/core';
import { from, last } from 'rxjs';
import { concatMap } from 'rxjs/operators';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import {
  filterBulkApplicableBpTimingProposals,
  filterBulkApplicableStageGddProposals
} from '../../domain/plans/learn-safe-proposal';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { ApplyBpTimingProposalFromLearnUseCase } from './apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from './apply-stage-gdd-calibration-from-learn.usecase';

export interface BulkApplySafeLearnProposalsInputDto {
  planId: number;
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>;
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>;
  onSuccess?: (appliedCount: number) => void;
  onError?: (message: string) => void;
}

type BulkApplyTarget =
  | { kind: 'stage_gdd'; proposal: StageGddCalibrationProposal }
  | { kind: 'bp_timing'; proposal: BlueprintTimingAdjustmentProposal };

@Injectable()
export class BulkApplySafeLearnProposalsUseCase {
  constructor(
    private readonly stageGddApplyUseCase: ApplyStageGddCalibrationFromLearnUseCase,
    private readonly bpTimingApplyUseCase: ApplyBpTimingProposalFromLearnUseCase
  ) {}

  execute(dto: BulkApplySafeLearnProposalsInputDto): void {
    const targets: BulkApplyTarget[] = [
      ...filterBulkApplicableStageGddProposals(dto.planId, dto.stageGddProposals).map(
        (proposal) => ({ kind: 'stage_gdd' as const, proposal })
      ),
      ...filterBulkApplicableBpTimingProposals(dto.planId, dto.blueprintTimingProposals).map(
        (proposal) => ({ kind: 'bp_timing' as const, proposal })
      )
    ];

    if (targets.length === 0) {
      dto.onSuccess?.(0);
      return;
    }

    from(targets)
      .pipe(
        concatMap((target) => this.applyTarget(dto.planId, target)),
        last()
      )
      .subscribe({
        next: () => dto.onSuccess?.(targets.length),
        error: (err: unknown) =>
          dto.onError?.(err instanceof Error ? err.message : 'plans.learn.bulk_apply.failed')
      });
  }

  private applyTarget(planId: number, target: BulkApplyTarget) {
    return new Promise<void>((resolve, reject) => {
      if (target.kind === 'stage_gdd') {
        const proposal = target.proposal;
        if (proposal.proposedRequiredGdd == null) {
          reject(new Error('plans.learn.bulk_apply.missing_proposed_gdd'));
          return;
        }
        this.stageGddApplyUseCase.execute({
          planId,
          cropId: proposal.cropId,
          stageId: proposal.stageId,
          proposedRequiredGdd: proposal.proposedRequiredGdd,
          onSuccess: () => resolve(),
          onError: (message) => reject(new Error(message))
        });
        return;
      }

      const proposal = target.proposal;
      this.bpTimingApplyUseCase.execute({
        planId,
        cropId: proposal.cropId,
        category: proposal.category,
        proposal: proposal.proposalBody,
        onSuccess: () => resolve(),
        onError: (message) => reject(new Error(message))
      });
    });
  }
}
