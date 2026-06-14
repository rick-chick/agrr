import { WorkRecord, WorkRecordUpdateRequest } from '../../models/plans/work-record';

export interface UpdateWorkRecordInputDto {
  planId: number;
  workRecordId: number;
  body: WorkRecordUpdateRequest;
  onSuccess?: () => void;
}

export interface UpdateWorkRecordSuccessDto {
  workRecord: WorkRecord;
}

export interface UpdateWorkRecordValidationErrorDto {
  fieldErrors: Record<string, string[]>;
}
