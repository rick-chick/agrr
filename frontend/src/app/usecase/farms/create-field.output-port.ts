import { InjectionToken } from '@angular/core';
import { CreateFieldOutputDto } from './create-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateFieldOutputPort {
  present(dto: CreateFieldOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_FIELD_OUTPUT_PORT = new InjectionToken<CreateFieldOutputPort>('CREATE_FIELD_OUTPUT_PORT');