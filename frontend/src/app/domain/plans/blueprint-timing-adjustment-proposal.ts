import type { CropSetupProposalBody } from '../crops/crop-setup-proposal';

export interface BlueprintTimingAdjustmentProposalRaw {
  crop_id: number;
  crop_name: string;
  category: string;
  average_delta_days: number;
  average_gdd_delta: number | null;
  recorded_item_count: number;
}

export interface BlueprintTimingAdjustmentProposal {
  cropId: number;
  cropName: string;
  category: string;
  averageDeltaDays: number;
  averageGddDelta: number | null;
  recordedItemCount: number;
  affectedBlueprintCount: number;
  proposalBody: CropSetupProposalBody;
}

export const BLUEPRINT_TIMING_PATCH_INTENT = 'blueprint_timing_patch';

export function blueprintTimingPrefillStorageKey(cropId: number): string {
  return `agrr:setup-proposal-prefill:${cropId}`;
}
