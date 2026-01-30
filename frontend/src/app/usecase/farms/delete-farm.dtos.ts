import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteFarmInputDto {
  farmId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeleteFarmSuccessDto {
  deletedFarmId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}
