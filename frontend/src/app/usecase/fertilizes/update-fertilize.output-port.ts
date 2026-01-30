import { InjectionToken } from '@angular/core';
import { UpdateFertilizeSuccessDto } from './update-fertilize.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface UpdateFertilizeOutputPort {
  onSuccess(dto: UpdateFertilizeSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const UPDATE_FERTILIZE_OUTPUT_PORT = new InjectionToken<UpdateFertilizeOutputPort>(
  'UPDATE_FERTILIZE_OUTPUT_PORT'
);
