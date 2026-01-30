import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Farm } from '../../domain/farms/farm';
import { Field } from '../../domain/farms/field';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { FarmGateway, FarmCreatePayload, FieldCreatePayload } from '../../usecase/farms/farm-gateway';

@Injectable()
export class FarmApiGateway implements FarmGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Farm[]> {
    return this.client.get<Farm[]>('/farms');
  }

  show(farmId: number): Observable<Farm> {
    return this.client.get<Farm>(`/farms/${farmId}`);
  }

  listFieldsByFarm(farmId: number): Observable<Field[]> {
    return this.client.get<Field[]>(`/farms/${farmId}/fields`);
  }

  create(payload: FarmCreatePayload): Observable<Farm> {
    return this.client.post<Farm>('/farms', { farm: payload });
  }

  update(farmId: number, payload: FarmCreatePayload): Observable<Farm> {
    return this.client.patch<Farm>(`/farms/${farmId}`, { farm: payload });
  }

  destroy(farmId: number): Observable<DeletionUndoResponse> {
    return this.client.delete<DeletionUndoResponse>(`/farms/${farmId}`);
  }

  createField(farmId: number, payload: FieldCreatePayload): Observable<Field> {
    return this.client.post<Field>(`/farms/${farmId}/fields`, { field: payload });
  }

  updateField(fieldId: number, payload: FieldCreatePayload): Observable<Field> {
    return this.client.patch<Field>(`/fields/${fieldId}`, { field: payload });
  }

  destroyField(fieldId: number): Observable<DeletionUndoResponse> {
    return this.client.delete<DeletionUndoResponse>(`/fields/${fieldId}`);
  }
}
