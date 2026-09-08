import { Farm } from '../../domain/farms/farm';

export interface LoadEntryScheduleFarmsInputDto {
  region: string;
}

export interface EntryScheduleFarmsDataDto {
  farms: Farm[];
}
