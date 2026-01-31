import { ThermalRequirement } from '../../domain/crops/crop';

export interface UpdateThermalRequirementInputDto {
  cropId: number;
  stageId: number;
  payload: {
    required_gdd?: number;
  };
}

export interface UpdateThermalRequirementOutputDto {
  requirement: ThermalRequirement;
}