import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import {
  WorkRecordCreateRequest,
  WorkRecordCreateResponse,
  WorkRecordDeleteResponse,
  WorkRecordUpdateRequest,
  WorkRecordUpdateResponse,
  WorkRecordsListResponse
} from '../../models/plans/work-record';

export interface WorkRecordGateway {
  listWorkRecords(planId: number, params?: { from?: string; to?: string; field_cultivation_id?: number }): Observable<WorkRecordsListResponse>;
  createWorkRecord(planId: number, body: WorkRecordCreateRequest): Observable<WorkRecordCreateResponse>;
  updateWorkRecord(planId: number, id: number, body: WorkRecordUpdateRequest): Observable<WorkRecordUpdateResponse>;
  deleteWorkRecord(planId: number, id: number): Observable<WorkRecordDeleteResponse>;
  skipTaskScheduleItem(planId: number, itemId: number): Observable<{ item: { id: number; status: string; cancelled_at: string | null } }>;
  unskipTaskScheduleItem(planId: number, itemId: number): Observable<{ item: { id: number; status: string; cancelled_at: string | null } }>;
}

export const WORK_RECORD_GATEWAY = new InjectionToken<WorkRecordGateway>('WORK_RECORD_GATEWAY');
