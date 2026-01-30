import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteFertilizeInputDto {
  fertilizeId: number;
  onAfterUndo?: () => void;
}

export interface DeleteFertilizeSuccessDto {
  deletedFertilizeId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}
