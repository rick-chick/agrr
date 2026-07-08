import { InjectionToken } from '@angular/core';
import {
  LoadGanttPlanDataEmptyDto,
  LoadGanttPlanDataErrorDto,
  LoadGanttPlanDataLoadedDto
} from './load-gantt-plan-data.dtos';

export interface LoadGanttPlanDataOutputPort {
  onPlanDataLoaded(dto: LoadGanttPlanDataLoadedDto): void;
  onPlanDataEmpty(dto: LoadGanttPlanDataEmptyDto): void;
  onLoadError(dto: LoadGanttPlanDataErrorDto): void;
}

export const LOAD_GANTT_PLAN_DATA_OUTPUT_PORT = new InjectionToken<LoadGanttPlanDataOutputPort>(
  'LOAD_GANTT_PLAN_DATA_OUTPUT_PORT'
);
