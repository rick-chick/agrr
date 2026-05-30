export interface SavePublicPlanInputDto {
  planId: number;
}

export interface SavePublicPlanSuccessDto {
  message: string;
  cultivation_plan_id?: number;
  plan_reused: boolean;
}
