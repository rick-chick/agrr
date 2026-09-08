import { InjectionToken } from '@angular/core';
import { EntryScheduleCropsDataDto } from './load-entry-schedule-crops.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadEntryScheduleCropsOutputPort {
  present(dto: EntryScheduleCropsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_ENTRY_SCHEDULE_CROPS_OUTPUT_PORT =
  new InjectionToken<LoadEntryScheduleCropsOutputPort>('LOAD_ENTRY_SCHEDULE_CROPS_OUTPUT_PORT');
