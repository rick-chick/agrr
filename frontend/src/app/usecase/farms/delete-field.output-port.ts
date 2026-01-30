import { InjectionToken } from '@angular/core';
import { DeleteFieldOutputDto } from './delete-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteFieldOutputPort {
  present(dto: DeleteFieldOutputDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_FIELD_OUTPUT_PORT = new InjectionToken<DeleteFieldOutputPort>('DELETE_FIELD_OUTPUT_PORT');