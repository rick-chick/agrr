import { InjectionToken } from '@angular/core';
import { UpdateFieldOutputDto } from './update-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateFieldOutputPort {
  present(dto: UpdateFieldOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_FIELD_OUTPUT_PORT = new InjectionToken<UpdateFieldOutputPort>('UPDATE_FIELD_OUTPUT_PORT');