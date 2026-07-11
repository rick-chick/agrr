import { InjectionToken } from '@angular/core';
import { LoadCrossFarmSchedulePresentDto } from './load-cross-farm-schedule.dtos';

export interface LoadCrossFarmScheduleOutputPort {
  presentSchedule(dto: LoadCrossFarmSchedulePresentDto): void;
  onScheduleError(dto: { message: string }): void;
  beginScheduleLoad(): void;
}

export const LOAD_CROSS_FARM_SCHEDULE_OUTPUT_PORT = new InjectionToken<LoadCrossFarmScheduleOutputPort>(
  'LOAD_CROSS_FARM_SCHEDULE_OUTPUT_PORT'
);
