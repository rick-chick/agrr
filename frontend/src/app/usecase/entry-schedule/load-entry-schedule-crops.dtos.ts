import { EntryScheduleCropsListResponse } from '../../domain/entry-schedule/entry-schedule';

export interface LoadEntryScheduleCropsInputDto {
  farmId: number;
  append: boolean;
  limit: number;
  cursor?: string | null;
}

export interface EntryScheduleCropsDataDto {
  response: EntryScheduleCropsListResponse;
  append: boolean;
}
