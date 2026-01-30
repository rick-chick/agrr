import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { Fertilize } from '../../models/masters/master-data';
export type { Fertilize };

export type FertilizePayload = {
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
};

@Injectable({ providedIn: 'root' })
export class FertilizeService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Fertilize[]> {
    return this.client.get<Fertilize[]>('/fertilizes');
  }

  show(id: number): Observable<Fertilize> {
    return this.client.get<Fertilize>(`/fertilizes/${id}`);
  }

  create(payload: FertilizePayload): Observable<Fertilize> {
    return this.client.post<Fertilize>('/fertilizes', { fertilize: payload });
  }

  update(id: number, payload: FertilizePayload): Observable<Fertilize> {
    return this.client.patch<Fertilize>(`/fertilizes/${id}`, { fertilize: payload });
  }

  destroy(id: number): Observable<void> {
    return this.client.delete<void>(`/fertilizes/${id}`);
  }
}
