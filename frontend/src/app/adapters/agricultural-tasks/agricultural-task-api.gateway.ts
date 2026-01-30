import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { AgriculturalTaskGateway, AgriculturalTaskCreatePayload } from '../../usecase/agricultural-tasks/agricultural-task-gateway';

@Injectable()
export class AgriculturalTaskApiGateway implements AgriculturalTaskGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<AgriculturalTask[]> {
    return this.client.get<AgriculturalTask[]>('/agricultural_tasks');
  }

  show(agriculturalTaskId: number): Observable<AgriculturalTask> {
    return this.client.get<AgriculturalTask>(`/agricultural_tasks/${agriculturalTaskId}`);
  }

  create(payload: AgriculturalTaskCreatePayload): Observable<AgriculturalTask> {
    return this.client.post<AgriculturalTask>('/agricultural_tasks', { agricultural_task: payload });
  }

  update(agriculturalTaskId: number, payload: AgriculturalTaskCreatePayload): Observable<AgriculturalTask> {
    return this.client.patch<AgriculturalTask>(`/agricultural_tasks/${agriculturalTaskId}`, { agricultural_task: payload });
  }

  destroy(agriculturalTaskId: number): Observable<DeletionUndoResponse> {
    return this.client.delete<DeletionUndoResponse>(`/agricultural_tasks/${agriculturalTaskId}`);
  }
}
