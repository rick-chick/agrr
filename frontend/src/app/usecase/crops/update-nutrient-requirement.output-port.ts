import { InjectionToken } from '@angular/core';
import { UpdateNutrientRequirementOutputDto } from './update-nutrient-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateNutrientRequirementOutputPort {
  present(dto: UpdateNutrientRequirementOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT = new InjectionToken<UpdateNutrientRequirementOutputPort>('UPDATE_NUTRIENT_REQUIREMENT_OUTPUT_PORT');