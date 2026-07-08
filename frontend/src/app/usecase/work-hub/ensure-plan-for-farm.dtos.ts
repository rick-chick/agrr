export interface EnsurePlanForFarmInputDto {
  farmId: number;
  existingPlanId: number | null;
}

export interface EnsurePlanForFarmSuccessDto {
  planId: number;
  created: boolean;
}
