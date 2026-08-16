import type { CropSetupProposalBody } from '../crops/crop-setup-proposal';

export interface BlueprintAmountAdjustmentProposalRaw {
  crop_id: number;
  crop_name: string;
  category: string;
  task_type: string;
  stage_order: number | null;
  stage_name: string | null;
  average_amount_delta: number;
  recorded_item_count: number;
  amount_unit: string | null;
}

export interface BlueprintAmountAdjustmentProposal {
  cropId: number;
  cropName: string;
  category: string;
  taskType: string;
  stageOrder: number | null;
  stageName: string | null;
  averageAmountDelta: number;
  recordedItemCount: number;
  amountUnit: string | null;
  affectedBlueprintCount: number;
  proposalBody: CropSetupProposalBody;
}

export const BLUEPRINT_AMOUNT_PATCH_INTENT = 'blueprint_amount_patch';

export function blueprintAmountProposalKey(
  cropId: number,
  category: string,
  taskType: string,
  stageOrder: number | null
): string {
  return `${cropId}-${category}-${taskType}-${stageOrder ?? 'null'}`;
}

export function blueprintAmountPrefillStorageKey(cropId: number): string {
  return `agrr:setup-proposal-prefill:${cropId}`;
}
