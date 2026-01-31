export interface DeleteCropStageInputDto {
  cropId: number;
  stageId: number;
}

export interface DeleteCropStageOutputDto {
  success: boolean;
  stageId: number;
}