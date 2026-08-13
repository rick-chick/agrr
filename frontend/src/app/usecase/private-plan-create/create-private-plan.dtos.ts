export interface CreatePrivatePlanInputDto {
  farmId: number;
  planName?: string;
  carryoverFromPlanId?: number;
  navigateToLearnAfterCreate?: boolean;
}

export interface CreatePrivatePlanResponseDto {
  id: number;
  navigateToLearnAfterCreate?: boolean;
}