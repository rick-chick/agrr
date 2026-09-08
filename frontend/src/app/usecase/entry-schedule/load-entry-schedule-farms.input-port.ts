import { LoadEntryScheduleFarmsInputDto } from './load-entry-schedule-farms.dtos';

export interface LoadEntryScheduleFarmsInputPort {
  execute(dto: LoadEntryScheduleFarmsInputDto): void;
}
