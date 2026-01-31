import { NutrientRequirement } from '../../domain/crops/crop';

export interface UpdateNutrientRequirementInputDto {
  cropId: number;
  stageId: number;
  payload: {
    daily_uptake_n?: number;
    daily_uptake_p?: number;
    daily_uptake_k?: number;
    region?: string;
  };
}

export interface UpdateNutrientRequirementOutputDto {
  requirement: NutrientRequirement;
}