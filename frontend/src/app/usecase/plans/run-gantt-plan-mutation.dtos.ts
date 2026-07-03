import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { GanttMutationFailureRecovery } from '../../domain/plans/gantt-plan-mutation';
import { GanttAddCropRequest, GanttAddFieldRequest } from './gantt-plan-mutation.dtos';

export type GanttMutationPresentationOptions = {
  onRefetchFailure?: GanttMutationFailureRecovery;
  revertBarOnMessageFailure?: boolean;
  onSuccess?: (data: CultivationPlanData) => void;
};

export type GanttPlanMutationCommand =
  | {
      kind: 'adjustCultivationMove';
      cultivationId: number;
      toFieldId: number;
      newStartDate: Date;
    }
  | { kind: 'addCrop'; payload: GanttAddCropRequest }
  | { kind: 'removeCultivation'; cultivationId: number }
  | { kind: 'addField'; payload: GanttAddFieldRequest }
  | { kind: 'removeField'; fieldId: number };

export interface RunGanttPlanMutationInputDto {
  planType: CultivationPlanContextType;
  planId: number;
  command: GanttPlanMutationCommand;
  presentation?: GanttMutationPresentationOptions;
}

export interface RunGanttPlanMutationResultDto {
  planId: number;
  presentation?: GanttMutationPresentationOptions;
}
