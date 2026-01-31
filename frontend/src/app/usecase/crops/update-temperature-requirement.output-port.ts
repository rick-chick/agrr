import { InjectionToken } from '@angular/core';
import { UpdateTemperatureRequirementOutputDto } from './update-temperature-requirement.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateTemperatureRequirementOutputPort {
  present(dto: UpdateTemperatureRequirementOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT = new InjectionToken<UpdateTemperatureRequirementOutputPort>('UPDATE_TEMPERATURE_REQUIREMENT_OUTPUT_PORT');