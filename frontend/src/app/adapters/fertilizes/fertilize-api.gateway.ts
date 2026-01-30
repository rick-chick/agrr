import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Fertilize } from '../../domain/fertilizes/fertilize';
import {
  FertilizeGateway,
  FertilizeCreatePayload
} from '../../usecase/fertilizes/fertilize-gateway';

@Injectable()
export class FertilizeApiGateway implements FertilizeGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Fertilize[]> {
    return this.client.get<Fertilize[]>('/fertilizes');
  }

  show(fertilizeId: number): Observable<Fertilize> {
    return this.client.get<Fertilize>(`/fertilizes/${fertilizeId}`);
  }

  create(payload: FertilizeCreatePayload): Observable<Fertilize> {
    return this.client.post<Fertilize>('/fertilizes', { fertilize: payload });
  }

  update(fertilizeId: number, payload: FertilizeCreatePayload): Observable<Fertilize> {
    return this.client.patch<Fertilize>(`/fertilizes/${fertilizeId}`, { fertilize: payload });
  }

  destroy(fertilizeId: number): Observable<void> {
    return this.client.delete<void>(`/fertilizes/${fertilizeId}`);
  }
}
