import { InjectionToken } from '@angular/core';
import { ResolveEntryScheduleFarmDataDto } from './resolve-entry-schedule-farm.dtos';

export interface ResolveEntryScheduleFarmOutputPort {
  presentFarm(dto: ResolveEntryScheduleFarmDataDto): void;
  onInvalidFarm(): void;
}

export const RESOLVE_ENTRY_SCHEDULE_FARM_OUTPUT_PORT =
  new InjectionToken<ResolveEntryScheduleFarmOutputPort>('RESOLVE_ENTRY_SCHEDULE_FARM_OUTPUT_PORT');
