import { WorkRecordCreateRequest, WorkRecordUpdateRequest } from '../../models/plans/work-record';
import { WorkRecordSheetMode } from '../../components/plans/work-record-sheet.view';

export interface SaveWorkRecordSheetInputDto {
  planId: number;
  mode: WorkRecordSheetMode;
  workRecordId?: number | null;
  createBody?: WorkRecordCreateRequest;
  updateBody?: WorkRecordUpdateRequest;
  pendingPhotoFiles: File[];
  photoIdsToDelete: number[];
}

export interface SaveWorkRecordSheetSuccessDto {
  workRecord: import('../../models/plans/work-record').WorkRecord;
  mode: WorkRecordSheetMode;
}

export interface SaveWorkRecordSheetValidationErrorDto {
  fieldErrors: Record<string, string[]>;
}
