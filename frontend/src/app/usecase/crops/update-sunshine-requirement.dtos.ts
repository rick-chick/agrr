import { SunshineRequirement } from '../../domain/crops/crop';

export interface UpdateSunshineRequirementInputDto {
  cropId: number;
  stageId: number;
  payload: {
    minimum_sunshine_hours?: number;
    target_sunshine_hours?: number;
  };
}

export interface UpdateSunshineRequirementOutputDto {
  requirement: SunshineRequirement;
}