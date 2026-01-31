import { UpdateSunshineRequirementInputDto } from './update-sunshine-requirement.dtos';

export interface UpdateSunshineRequirementInputPort {
  execute(dto: UpdateSunshineRequirementInputDto): void;
}