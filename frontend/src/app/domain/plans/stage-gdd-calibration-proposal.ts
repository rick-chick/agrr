export interface StageGddCalibrationProposalRaw {
  crop_id: number;
  crop_name: string;
  stage_order: number;
  stage_name: string;
  average_gdd_delta: number;
  recorded_item_count: number;
}

export interface StageGddCalibrationProposal {
  cropId: number;
  cropName: string;
  stageId: number;
  stageOrder: number;
  stageName: string;
  averageGddDelta: number;
  recordedItemCount: number;
  currentRequiredGdd: number | null;
  proposedRequiredGdd: number | null;
}
