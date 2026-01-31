import { InjectionToken } from '@angular/core';
import { UpdateSunshineRequirementOutputDto } from './update-sunshine-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateSunshineRequirementOutputPort {
  present(dto: UpdateSunshineRequirementOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT = new InjectionToken<UpdateSunshineRequirementOutputPort>('UPDATE_SUNSHINE_REQUIREMENT_OUTPUT_PORT');