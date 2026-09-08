import { InjectionToken } from '@angular/core';
import { EntryScheduleFarmsDataDto } from './load-entry-schedule-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadEntryScheduleFarmsOutputPort {
  present(dto: EntryScheduleFarmsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_ENTRY_SCHEDULE_FARMS_OUTPUT_PORT =
  new InjectionToken<LoadEntryScheduleFarmsOutputPort>('LOAD_ENTRY_SCHEDULE_FARMS_OUTPUT_PORT');
