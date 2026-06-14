import { WorkRecord } from '../../models/plans/work-record';

export interface WorkRecordMonthGroupDto {
  monthLabel: string;
  records: WorkRecord[];
}

export interface LoadWorkRecordsInputDto {
  planId: number;
}

export interface WorkRecordsPlanHeaderDto {
  id: number;
  name: string;
}

export interface LoadWorkRecordsDataDto {
  plan: WorkRecordsPlanHeaderDto;
  groups: WorkRecordMonthGroupDto[];
}
