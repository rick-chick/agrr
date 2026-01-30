import { InjectionToken } from '@angular/core';
import { CreateFertilizeSuccessDto } from './create-fertilize.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface CreateFertilizeOutputPort {
  onSuccess(dto: CreateFertilizeSuccessDto): void;
  onError(dto: ErrorDto): void;
}

export const CREATE_FERTILIZE_OUTPUT_PORT = new InjectionToken<CreateFertilizeOutputPort>(
  'CREATE_FERTILIZE_OUTPUT_PORT'
);
