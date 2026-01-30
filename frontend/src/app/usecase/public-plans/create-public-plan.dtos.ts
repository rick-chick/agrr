import { CreatePublicPlanResponse } from './public-plan-gateway';

export interface CreatePublicPlanInputDto {
  farmId: number;
  farmSizeId: string;
  cropIds: number[];
  onSuccess?: (response: CreatePublicPlanResponse) => void;
}
