import { WorkRecord } from '../../models/plans/work-record';
import { WorkRecordCreateRequest } from '../../models/plans/work-record';

export interface CreateWorkRecordInputDto {
  planId: number;
  body: WorkRecordCreateRequest;
  onSuccess?: () => void;
}

export interface CreateWorkRecordSuccessDto {
  workRecord: WorkRecord;
}

export interface CreateWorkRecordValidationErrorDto {
  fieldErrors: Record<string, string[]>;
}
