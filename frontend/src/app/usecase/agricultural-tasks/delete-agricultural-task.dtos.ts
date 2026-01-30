import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteAgriculturalTaskInputDto {
  agriculturalTaskId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeleteAgriculturalTaskSuccessDto {
  deletedAgriculturalTaskId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}