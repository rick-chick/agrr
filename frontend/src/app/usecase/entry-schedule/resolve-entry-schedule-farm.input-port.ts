import { ResolveEntryScheduleFarmInputDto } from './resolve-entry-schedule-farm.dtos';

export interface ResolveEntryScheduleFarmInputPort {
  execute(dto: ResolveEntryScheduleFarmInputDto): void;
}
