import { LoadEntryScheduleCropsInputDto } from './load-entry-schedule-crops.dtos';

export interface LoadEntryScheduleCropsInputPort {
  execute(dto: LoadEntryScheduleCropsInputDto): void;
}
