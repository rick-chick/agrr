import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeletePestInputDto {
  pestId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeletePestSuccessDto {
  deletedPestId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}