import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeletePlanInputDto {
  planId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeletePlanSuccessDto {
  deletedPlanId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}
