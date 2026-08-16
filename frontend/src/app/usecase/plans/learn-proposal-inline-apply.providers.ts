import { Provider } from '@angular/core';
import { CropSetupProposalApiGateway } from '../../adapters/crops/crop-setup-proposal-api.gateway';
import { CropStageApiGateway } from '../../adapters/crops/crop-stage-api.gateway';
import { CROP_SETUP_PROPOSAL_GATEWAY } from '../crops/crop-setup-proposal-gateway';
import { CROP_STAGE_GATEWAY } from '../crops/crop-stage-gateway';
import { ApplyBpAmountProposalFromLearnUseCase } from './apply-bp-amount-proposal-from-learn.usecase';
import { ApplyBpTimingProposalFromLearnUseCase } from './apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from './apply-stage-gdd-calibration-from-learn.usecase';
import { DryRunBpAmountProposalFromLearnUseCase } from './dry-run-bp-amount-proposal-from-learn.usecase';
import { DryRunBpTimingProposalFromLearnUseCase } from './dry-run-bp-timing-proposal-from-learn.usecase';

export const LEARN_PROPOSAL_INLINE_APPLY_PROVIDERS: readonly Provider[] = [
  ApplyStageGddCalibrationFromLearnUseCase,
  ApplyBpTimingProposalFromLearnUseCase,
  ApplyBpAmountProposalFromLearnUseCase,
  DryRunBpTimingProposalFromLearnUseCase,
  DryRunBpAmountProposalFromLearnUseCase,
  { provide: CROP_STAGE_GATEWAY, useClass: CropStageApiGateway },
  { provide: CROP_SETUP_PROPOSAL_GATEWAY, useClass: CropSetupProposalApiGateway }
];
