import { InjectionToken } from '@angular/core';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';

export interface LoadStageGddCalibrationProposalsDataDto {
  loadGeneration: number;
  proposals: StageGddCalibrationProposal[];
}

export interface LoadStageGddCalibrationProposalsOutputPort {
  presentStageGddProposals(dto: LoadStageGddCalibrationProposalsDataDto): void;
}

export const LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT =
  new InjectionToken<LoadStageGddCalibrationProposalsOutputPort>(
    'LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT'
  );
