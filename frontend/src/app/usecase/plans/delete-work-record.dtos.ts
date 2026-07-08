import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface DeleteWorkRecordInputDto {
  planId: number;
  workRecordId: number;
}

export interface DeleteWorkRecordSuccessDto {
  undo: DeletionUndoResponse;
}
