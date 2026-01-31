import { UpdateNutrientRequirementInputDto } from './update-nutrient-requirement.dtos';

export interface UpdateNutrientRequirementInputPort {
  execute(dto: UpdateNutrientRequirementInputDto): void;
}