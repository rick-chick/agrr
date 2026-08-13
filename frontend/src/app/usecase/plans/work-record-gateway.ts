import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import {
  TaskScheduleItemCreateRequest,
  TaskScheduleItemMutationResponse,
  TaskScheduleItemUpdateRequest
} from '../../models/plans/task-schedule';
import {
  WorkRecordCreateRequest,
  WorkRecordCreateResponse,
  WorkRecordUpdateRequest,
  WorkRecordUpdateResponse,
  WorkRecordsListResponse
} from '../../models/plans/work-record';

export interface WorkRecordGateway {
  listWorkRecords(planId: number, params?: { from?: string; to?: string; field_cultivation_id?: number }): Observable<WorkRecordsListResponse>;
  createWorkRecord(planId: number, body: WorkRecordCreateRequest): Observable<WorkRecordCreateResponse>;
  updateWorkRecord(planId: number, id: number, body: WorkRecordUpdateRequest): Observable<WorkRecordUpdateResponse>;
  deleteWorkRecord(planId: number, id: number): Observable<DeletionUndoResponse>;
  skipTaskScheduleItem(planId: number, itemId: number): Observable<{ item: { id: number; status: string; cancelled_at: string | null } }>;
  unskipTaskScheduleItem(planId: number, itemId: number): Observable<{ item: { id: number; status: string; cancelled_at: string | null } }>;
  createTaskScheduleItem(
    planId: number,
    body: TaskScheduleItemCreateRequest
  ): Observable<TaskScheduleItemMutationResponse>;
  updateTaskScheduleItem(
    planId: number,
    itemId: number,
    body: TaskScheduleItemUpdateRequest
  ): Observable<TaskScheduleItemMutationResponse>;
}

export const WORK_RECORD_GATEWAY = new InjectionToken<WorkRecordGateway>('WORK_RECORD_GATEWAY');
