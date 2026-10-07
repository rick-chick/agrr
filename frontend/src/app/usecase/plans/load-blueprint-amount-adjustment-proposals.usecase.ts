import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { map } from 'rxjs/operators';
import { buildBlueprintAmountAdjustmentProposals } from '../../domain/plans/build-blueprint-amount-adjustment-proposals';
import {
  CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY,
  CropTaskScheduleBlueprintGateway
} from '../crops/crop-task-schedule-blueprint-gateway';
import {
  LOAD_BLUEPRINT_AMOUNT_ADJUSTMENT_PROPOSALS_OUTPUT_PORT,
  LoadBlueprintAmountAdjustmentProposalsInputDto,
  LoadBlueprintAmountAdjustmentProposalsOutputPort
} from './load-blueprint-amount-adjustment-proposals.output-port';

@Injectable()
export class LoadBlueprintAmountAdjustmentProposalsUseCase {
  constructor(
    @Inject(LOAD_BLUEPRINT_AMOUNT_ADJUSTMENT_PROPOSALS_OUTPUT_PORT)
    private readonly outputPort: LoadBlueprintAmountAdjustmentProposalsOutputPort,
    @Inject(CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY)
    private readonly blueprintGateway: CropTaskScheduleBlueprintGateway
  ) {}

  execute(dto: LoadBlueprintAmountAdjustmentProposalsInputDto): void {
    const cropIds = [...new Set(dto.rawProposals.map((proposal) => proposal.crop_id))];
    if (cropIds.length === 0) {
      this.outputPort.presentBlueprintAmountProposals({
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
        const proposals = buildBlueprintAmountAdjustmentProposals(
          dto.rawProposals,
          blueprintsByCropId
        );
        this.outputPort.presentBlueprintAmountProposals({
          loadGeneration: dto.loadGeneration,
          proposals
        });
      },
      error: () =>
        this.outputPort.presentBlueprintAmountProposals({
          loadGeneration: dto.loadGeneration,
          proposals: []
        })
    });
  }
}
