import { InjectionToken } from '@angular/core';
import {
  CropSetupProposalApplyResponse,
  CropSetupProposalBody,
  CropSetupProposalDryRunResponse
} from '../../domain/crops/crop-setup-proposal';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DryRunCropSetupProposalInputDto {
  cropId: number;
  proposal: CropSetupProposalBody;
}

export interface DryRunCropSetupProposalInputPort {
  execute(dto: DryRunCropSetupProposalInputDto): void;
}

export interface DryRunCropSetupProposalOutputPort {
  onDryRunStarted(): void;
  onDryRunSuccess(dto: CropSetupProposalDryRunResponse): void;
  onError(dto: ErrorDto): void;
}

export const DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT =
  new InjectionToken<DryRunCropSetupProposalOutputPort>('DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT');

export interface ApplyCropSetupProposalInputDto {
  cropId: number;
  proposal: CropSetupProposalBody;
  onSuccess?: () => void;
}

export interface ApplyCropSetupProposalInputPort {
  execute(dto: ApplyCropSetupProposalInputDto): void;
}

export interface ApplyCropSetupProposalOutputPort {
  onApplyStarted(): void;
  onApplySuccess(dto: CropSetupProposalApplyResponse): void;
  onError(dto: ErrorDto): void;
}

export const APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT = new InjectionToken<ApplyCropSetupProposalOutputPort>(
  'APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT'
);
