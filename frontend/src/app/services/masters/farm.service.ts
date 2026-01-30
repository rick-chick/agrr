import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { Farm } from '../../models/masters/master-data';

export type FarmPayload = {
  name: string;
  latitude: number;
  longitude: number;
  region: string;
};

@Injectable({ providedIn: 'root' })
export class FarmService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Farm[]> {
    return this.client.get<Farm[]>('/farms');
  }

  show(id: number): Observable<Farm> {
    return this.client.get<Farm>(`/farms/${id}`);
  }

  create(payload: FarmPayload): Observable<Farm> {
    return this.client.post<Farm>('/farms', { farm: payload });
  }

  update(id: number, payload: FarmPayload): Observable<Farm> {
    return this.client.patch<Farm>(`/farms/${id}`, { farm: payload });
  }

  destroy(id: number): Observable<void> {
    return this.client.delete<void>(`/farms/${id}`);
  }
}
