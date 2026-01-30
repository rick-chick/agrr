import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteInteractionRuleInputDto {
  interactionRuleId: number;
  onSuccess?: () => void;
  onAfterUndo?: () => void;
}

export interface DeleteInteractionRuleSuccessDto {
  deletedInteractionRuleId: number;
  undo?: DeletionUndoResponse;
  refresh?: () => void;
}