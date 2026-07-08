import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

export type LoadGanttPlanDataPurpose = 'refresh' | 'reset_bar';

export interface LoadGanttPlanDataInputDto {
  planType: CultivationPlanContextType;
  planId: number;
  purpose: LoadGanttPlanDataPurpose;
}

export interface LoadGanttPlanDataLoadedDto {
  data: CultivationPlanData;
  purpose: LoadGanttPlanDataPurpose;
}

export interface LoadGanttPlanDataEmptyDto {
  purpose: LoadGanttPlanDataPurpose;
}

export interface LoadGanttPlanDataErrorDto {
  message?: string;
  purpose: LoadGanttPlanDataPurpose;
}
