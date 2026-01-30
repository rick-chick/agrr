import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteCropInputDto {
  cropId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeleteCropSuccessDto {
  deletedCropId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}
