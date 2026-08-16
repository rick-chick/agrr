import type { BlueprintAmountAdjustmentProposal } from '../../domain/plans/blueprint-amount-adjustment-proposal';

export interface LoadBlueprintAmountAdjustmentProposalsInputDto {
  rawProposals: ReadonlyArray<{
    crop_id: number;
    crop_name: string;
    category: string;
    task_type: string;
    stage_order: number | null;
    stage_name: string | null;
    average_amount_delta: number;
    recorded_item_count: number;
    amount_unit: string | null;
  }>;
  loadGeneration: number;
}

export interface LoadBlueprintAmountAdjustmentProposalsOutputDto {
  loadGeneration: number;
  proposals: BlueprintAmountAdjustmentProposal[];
}

export interface LoadBlueprintAmountAdjustmentProposalsOutputPort {
  presentBlueprintAmountProposals(dto: LoadBlueprintAmountAdjustmentProposalsOutputDto): void;
}

export const LOAD_BLUEPRINT_AMOUNT_ADJUSTMENT_PROPOSALS_OUTPUT_PORT =
  'LOAD_BLUEPRINT_AMOUNT_ADJUSTMENT_PROPOSALS_OUTPUT_PORT';
