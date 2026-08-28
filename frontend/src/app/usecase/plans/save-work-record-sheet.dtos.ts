import { WorkRecordCreateRequest, WorkRecordUpdateRequest } from '../../models/plans/work-record';
import { WorkRecordSheetMode } from '../../components/plans/work-record-sheet.view';

export interface DeletedWorkRecordPhotoBackup {
  photoId: number;
  blob: Blob;
}

export interface SaveWorkRecordSheetInputDto {
  planId: number;
  mode: WorkRecordSheetMode;
  workRecordId?: number | null;
  createBody?: WorkRecordCreateRequest;
  updateBody?: WorkRecordUpdateRequest;
  pendingPhotoFiles: File[];
  photoIdsToDelete: number[];
  /** Blobs of photos marked for delete; used to compensate when upload fails after delete. */
  deletedPhotoBackups: DeletedWorkRecordPhotoBackup[];
}

export interface SaveWorkRecordSheetSuccessDto {
  workRecord: import('../../models/plans/work-record').WorkRecord;
  mode: WorkRecordSheetMode;
}

export interface SaveWorkRecordSheetValidationErrorDto {
  fieldErrors: Record<string, string[]>;
}

export interface SaveWorkRecordSheetPhotoPartialFailureDto {
  workRecord: import('../../models/plans/work-record').WorkRecord;
}
