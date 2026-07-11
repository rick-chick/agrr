import type { CrossFarmScheduleRow } from '../../domain/work-schedule/cross-farm-schedule-row';

export interface LoadCrossFarmSchedulePresentDto {
  rows: CrossFarmScheduleRow[];
}
