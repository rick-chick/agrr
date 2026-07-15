export interface ReorderCropStagesInputDto {
  cropId: number;
  orders: Array<{ id: number; order: number }>;
}
