import { InjectionToken } from '@angular/core';
import { EntryScheduleCropDataDto } from './load-entry-schedule-crop.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

export interface LoadEntryScheduleCropOutputPort {
  present(dto: EntryScheduleCropDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_ENTRY_SCHEDULE_CROP_OUTPUT_PORT =
  new InjectionToken<LoadEntryScheduleCropOutputPort>('LOAD_ENTRY_SCHEDULE_CROP_OUTPUT_PORT');
