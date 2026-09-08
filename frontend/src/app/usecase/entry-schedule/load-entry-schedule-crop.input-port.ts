import { LoadEntryScheduleCropInputDto } from './load-entry-schedule-crop.dtos';

export interface LoadEntryScheduleCropInputPort {
  execute(dto: LoadEntryScheduleCropInputDto): void;
}
