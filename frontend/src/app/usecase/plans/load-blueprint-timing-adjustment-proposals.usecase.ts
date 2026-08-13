import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { map } from 'rxjs/operators';
import { buildBlueprintTimingAdjustmentProposals } from '../../domain/plans/build-blueprint-timing-adjustment-proposals';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from '../crops/crop-task-schedule-blueprint-gateway';
import {
  LOAD_BLUEPRINT_TIMING_ADJUSTMENT_PROPOSALS_OUTPUT_PORT,
  LoadBlueprintTimingAdjustmentProposalsInputDto,
  LoadBlueprintTimingAdjustmentProposalsOutputPort
} from './load-blueprint-timing-adjustment-proposals.output-port';

@Injectable()
export class LoadBlueprintTimingAdjustmentProposalsUseCase {
  constructor(
    @Inject(LOAD_BLUEPRINT_TIMING_ADJUSTMENT_PROPOSALS_OUTPUT_PORT)
    private readonly outputPort: LoadBlueprintTimingAdjustmentProposalsOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly blueprintGateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: LoadBlueprintTimingAdjustmentProposalsInputDto): void {
    const cropIds = [...new Set(dto.rawProposals.map((proposal) => proposal.crop_id))];
    if (cropIds.length === 0) {
      this.outputPort.presentBlueprintTimingProposals({
        loadGeneration: dto.loadGeneration,
        proposals: []
      });
      return;
    }

    forkJoin(
      cropIds.map((cropId) =>
        this.blueprintGateway
          .list(cropId)
          .pipe(map((blueprints) => [cropId, blueprints] as const))
      )
    ).subscribe({
      next: (entries) => {
        const blueprintsByCropId = new Map(entries);
        const proposals = buildBlueprintTimingAdjustmentProposals(
          dto.rawProposals,
          blueprintsByCropId
        );
        this.outputPort.presentBlueprintTimingProposals({
          loadGeneration: dto.loadGeneration,
          proposals
        });
      },
      error: () =>
        this.outputPort.presentBlueprintTimingProposals({
          loadGeneration: dto.loadGeneration,
          proposals: []
        })
    });
  }
}
