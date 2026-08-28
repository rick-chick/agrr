import { WorkRecordCreateRequest, WorkRecordUpdateRequest } from '../../models/plans/work-record';
import { WorkRecordSheetMode } from '../../components/plans/work-record-sheet.view';

export interface DeletedWorkRecordPhotoSource {
  photoId: number;
  contentUrl: string;
}

export interface SaveWorkRecordSheetInputDto {
  planId: number;
  mode: WorkRecordSheetMode;
  workRecordId?: number | null;
  createBody?: WorkRecordCreateRequest;
  updateBody?: WorkRecordUpdateRequest;
  pendingPhotoFiles: File[];
  photoIdsToDelete: number[];
  /** URLs for photos marked delete; used to compensate when upload fails after delete. */
  deletedPhotoContentUrls: DeletedWorkRecordPhotoSource[];
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
