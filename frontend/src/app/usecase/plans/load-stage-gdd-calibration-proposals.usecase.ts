import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { map } from 'rxjs/operators';
import { buildStageGddCalibrationProposals } from '../../domain/plans/build-stage-gdd-calibration-proposals';
import type { StageGddCalibrationProposalRaw } from '../../domain/plans/stage-gdd-calibration-proposal';
import { CROP_GATEWAY, CropGateway } from '../crops/crop-gateway';
import {
  LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT,
  LoadStageGddCalibrationProposalsOutputPort
} from './load-stage-gdd-calibration-proposals.output-port';

export interface LoadStageGddCalibrationProposalsInputDto {
  rawProposals: ReadonlyArray<StageGddCalibrationProposalRaw>;
  loadGeneration: number;
}

@Injectable()
export class LoadStageGddCalibrationProposalsUseCase {
  constructor(
    @Inject(LOAD_STAGE_GDD_CALIBRATION_PROPOSALS_OUTPUT_PORT)
    private readonly outputPort: LoadStageGddCalibrationProposalsOutputPort,
    @Inject(CROP_GATEWAY) private readonly cropGateway: CropGateway
  ) {}

  execute(dto: LoadStageGddCalibrationProposalsInputDto): void {
    const cropIds = [...new Set(dto.rawProposals.map((proposal) => proposal.crop_id))];
    if (cropIds.length === 0) {
      this.outputPort.presentStageGddProposals({
        loadGeneration: dto.loadGeneration,
        proposals: []
      });
      return;
    }

    forkJoin(
      cropIds.map((cropId) =>
        this.cropGateway.show(cropId).pipe(map((crop) => [cropId, crop.crop_stages ?? []] as const))
      )
    ).subscribe({
      next: (entries) => {
        const cropStagesByCropId = new Map(entries);
        const proposals = buildStageGddCalibrationProposals(
          dto.rawProposals,
          cropStagesByCropId
        );
        this.outputPort.presentStageGddProposals({
          loadGeneration: dto.loadGeneration,
          proposals
        });
      },
      error: () =>
        this.outputPort.presentStageGddProposals({
          loadGeneration: dto.loadGeneration,
          proposals: []
        })
    });
  }
}
