export interface CreatePrivatePlanInputDto {
  farmId: number;
  planName?: string;
  carryoverFromPlanId?: number;
}

export interface CreatePrivatePlanResponseDto {
  id: number;
}