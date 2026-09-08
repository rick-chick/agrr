import { EntryScheduleCropShowResponse } from '../../domain/entry-schedule/entry-schedule';

export interface LoadEntryScheduleCropInputDto {
  farmId: number;
  cropId: number;
}

export interface EntryScheduleCropDataDto {
  data: EntryScheduleCropShowResponse;
}
