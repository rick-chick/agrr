import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeletePesticideInputDto {
  pesticideId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeletePesticideSuccessDto {
  deletedPesticideId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}