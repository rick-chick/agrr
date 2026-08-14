import { Inject, Injectable } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { collectSafeLearnProposals } from '../../domain/plans/is-safe-learn-proposal';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { CROP_SETUP_PROPOSAL_GATEWAY, CropSetupProposalGateway } from '../crops/crop-setup-proposal-gateway';
import { CROP_STAGE_GATEWAY, CropStageGateway } from '../crops/crop-stage-gateway';
import { upsertThermalRequirement } from '../crops/crop-stage-requirement-gateway-ops';
import {
  bpTimingProposalProgressKey,
  markLearnProposalConfirmed,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';

export interface BulkApplySafeLearnProposalsInputDto {
  planId: number;
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>;
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>;
  onComplete?: (result: BulkApplySafeLearnProposalsResult) => void;
  onError?: (message: string, result: BulkApplySafeLearnProposalsResult) => void;
}

export interface BulkApplySafeLearnProposalsResult {
  appliedCount: number;
  failedCount: number;
}

@Injectable()
export class BulkApplySafeLearnProposalsUseCase {
  constructor(
    @Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway,
    @Inject(CROP_SETUP_PROPOSAL_GATEWAY) private readonly setupProposalGateway: CropSetupProposalGateway
  ) {}

  async execute(dto: BulkApplySafeLearnProposalsInputDto): Promise<void> {
    const safe = collectSafeLearnProposals(
      dto.planId,
      dto.stageGddProposals,
      dto.blueprintTimingProposals
    );
    const queue = [
      ...safe.stageGdd.map((proposal) => ({ kind: 'stage_gdd' as const, proposal })),
      ...safe.bpTiming.map((proposal) => ({ kind: 'bp_timing' as const, proposal }))
    ];
    let appliedCount = 0;
    let failedCount = 0;

    for (const item of queue) {
      try {
        if (item.kind === 'stage_gdd') {
          await this.applyStageGdd(dto.planId, item.proposal);
        } else {
          await this.applyBpTiming(dto.planId, item.proposal);
        }
        appliedCount += 1;
      } catch (error) {
        failedCount += 1;
        dto.onError?.(apiErrorI18nKey(error), { appliedCount, failedCount });
        return;
      }
    }

    dto.onComplete?.({ appliedCount, failedCount });
  }

  private async applyStageGdd(
    planId: number,
    proposal: StageGddCalibrationProposal
  ): Promise<void> {
    if (proposal.proposedRequiredGdd == null) {
      throw new Error('missing proposedRequiredGdd');
    }
    await firstValueFrom(
      upsertThermalRequirement(this.cropStageGateway, proposal.cropId, proposal.stageId, {
        required_gdd: proposal.proposedRequiredGdd
      })
    );
    markLearnProposalConfirmed(
      planId,
      stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
    );
  }

  private async applyBpTiming(
    planId: number,
    proposal: BlueprintTimingAdjustmentProposal
  ): Promise<void> {
    const response = await firstValueFrom(
      this.setupProposalGateway.apply(proposal.cropId, proposal.proposalBody)
    );
    if (response.valid !== true) {
      throw new Error('crops.setup_proposal_import.apply_failed');
    }
    markLearnProposalConfirmed(
      planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
  }
}
