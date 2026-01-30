import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteFieldInputDto {
  fieldId: number;
  farmId: number;
}

export interface DeleteFieldOutputDto {
  undo?: DeletionUndoResponse;
  farmId: number;
}