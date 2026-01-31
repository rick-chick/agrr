import { UpdateThermalRequirementInputDto } from './update-thermal-requirement.dtos';

export interface UpdateThermalRequirementInputPort {
  execute(dto: UpdateThermalRequirementInputDto): void;
}