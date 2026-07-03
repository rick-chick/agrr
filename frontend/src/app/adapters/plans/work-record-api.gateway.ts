import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import {
  WorkRecordCreateRequest,
  WorkRecordCreateResponse,
  WorkRecordUpdateRequest,
  WorkRecordUpdateResponse,
  WorkRecordsListResponse
} from '../../models/plans/work-record';
import { ApiService } from '../../services/api.service';
import { WorkRecordGateway } from '../../usecase/plans/work-record-gateway';

@Injectable()
export class WorkRecordApiGateway implements WorkRecordGateway {
  constructor(private readonly apiClient: ApiService) {}

  listWorkRecords(
    planId: number,
    params?: { from?: string; to?: string; field_cultivation_id?: number }
  ): Observable<WorkRecordsListResponse> {
    const query = new URLSearchParams();
    if (params?.from) query.set('from', params.from);
    if (params?.to) query.set('to', params.to);
    if (params?.field_cultivation_id != null) {
      query.set('field_cultivation_id', String(params.field_cultivation_id));
    }
    const qs = query.toString();
    const path = `/api/v1/plans/${planId}/work_records${qs ? `?${qs}` : ''}`;
    return this.apiClient.get<WorkRecordsListResponse>(path);
  }

  createWorkRecord(planId: number, body: WorkRecordCreateRequest): Observable<WorkRecordCreateResponse> {
    return this.apiClient.post<WorkRecordCreateResponse>(`/api/v1/plans/${planId}/work_records`, {
      work_record: body
    });
  }

  updateWorkRecord(
    planId: number,
    id: number,
    body: WorkRecordUpdateRequest
  ): Observable<WorkRecordUpdateResponse> {
    return this.apiClient.patch<WorkRecordUpdateResponse>(
      `/api/v1/plans/${planId}/work_records/${id}`,
      { work_record: body }
    );
  }

  deleteWorkRecord(planId: number, id: number): Observable<DeletionUndoResponse> {
    return this.apiClient.delete<DeletionUndoResponse>(`/api/v1/plans/${planId}/work_records/${id}`);
  }

  skipTaskScheduleItem(
    planId: number,
    itemId: number
  ): Observable<{ item: { id: number; status: string; cancelled_at: string | null } }> {
    return this.apiClient.patch<{ item: { id: number; status: string; cancelled_at: string | null } }>(
      `/api/v1/plans/${planId}/task_schedule/items/${itemId}/skip`,
      {}
    );
  }

  unskipTaskScheduleItem(
    planId: number,
    itemId: number
  ): Observable<{ item: { id: number; status: string; cancelled_at: string | null } }> {
    return this.apiClient.patch<{ item: { id: number; status: string; cancelled_at: string | null } }>(
      `/api/v1/plans/${planId}/task_schedule/items/${itemId}/unskip`,
      {}
    );
  }
}
