import { InjectionToken } from '@angular/core';
import { DeleteFertilizeSuccessDto } from './delete-fertilize.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface DeleteFertilizeOutputPort {
  onSuccess(dto: DeleteFertilizeSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const DELETE_FERTILIZE_OUTPUT_PORT = new InjectionToken<DeleteFertilizeOutputPort>(
  'DELETE_FERTILIZE_OUTPUT_PORT'
);
