import { InjectionToken } from '@angular/core';
import { UpdateThermalRequirementOutputDto } from './update-thermal-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateThermalRequirementOutputPort {
  present(dto: UpdateThermalRequirementOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT = new InjectionToken<UpdateThermalRequirementOutputPort>('UPDATE_THERMAL_REQUIREMENT_OUTPUT_PORT');