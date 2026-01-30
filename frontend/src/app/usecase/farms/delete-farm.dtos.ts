export interface DeleteFarmInputDto {
  farmId: number;
  onSuccess?: () => void;
}

export interface DeleteFarmSuccessDto {
  deletedFarmId: number;
}
