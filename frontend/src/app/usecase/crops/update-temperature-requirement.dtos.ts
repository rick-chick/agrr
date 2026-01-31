import { TemperatureRequirement } from '../../domain/crops/crop';

export interface UpdateTemperatureRequirementInputDto {
  cropId: number;
  stageId: number;
  payload: {
    base_temperature?: number;
    optimal_min?: number;
    optimal_max?: number;
    low_stress_threshold?: number;
    high_stress_threshold?: number;
    frost_threshold?: number;
    sterility_risk_threshold?: number;
    max_temperature?: number;
  };
}

export interface UpdateTemperatureRequirementOutputDto {
  requirement: TemperatureRequirement;
}