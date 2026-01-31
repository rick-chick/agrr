import { UpdateTemperatureRequirementInputDto } from './update-temperature-requirement.dtos';

export interface UpdateTemperatureRequirementInputPort {
  execute(dto: UpdateTemperatureRequirementInputDto): void;
}