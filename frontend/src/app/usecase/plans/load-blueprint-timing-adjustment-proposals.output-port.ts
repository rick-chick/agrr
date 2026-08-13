import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';

export interface LoadBlueprintTimingAdjustmentProposalsInputDto {
  rawProposals: ReadonlyArray<{
    crop_id: number;
    crop_name: string;
    category: string;
    average_delta_days: number;
    average_gdd_delta: number | null;
    recorded_item_count: number;
  }>;
  loadGeneration: number;
}

export interface LoadBlueprintTimingAdjustmentProposalsOutputDto {
  loadGeneration: number;
  proposals: BlueprintTimingAdjustmentProposal[];
}

export interface LoadBlueprintTimingAdjustmentProposalsOutputPort {
  presentBlueprintTimingProposals(dto: LoadBlueprintTimingAdjustmentProposalsOutputDto): void;
}

export const LOAD_BLUEPRINT_TIMING_ADJUSTMENT_PROPOSALS_OUTPUT_PORT =
  'LOAD_BLUEPRINT_TIMING_ADJUSTMENT_PROPOSALS_OUTPUT_PORT';
