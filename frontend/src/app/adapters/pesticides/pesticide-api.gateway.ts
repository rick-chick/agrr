import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pesticide } from '../../domain/pesticides/pesticide';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { PesticideGateway, PesticideCreatePayload } from '../../usecase/pesticides/pesticide-gateway';

@Injectable()
export class PesticideApiGateway implements PesticideGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Pesticide[]> {
    return this.client.get<Pesticide[]>('/pesticides');
  }

  show(pesticideId: number): Observable<Pesticide> {
    return this.client.get<Pesticide>(`/pesticides/${pesticideId}`);
  }

  create(payload: PesticideCreatePayload): Observable<Pesticide> {
    return this.client.post<Pesticide>('/pesticides', { pesticide: payload });
  }

  update(pesticideId: number, payload: PesticideCreatePayload): Observable<Pesticide> {
    return this.client.patch<Pesticide>(`/pesticides/${pesticideId}`, { pesticide: payload });
  }

  destroy(pesticideId: number): Observable<DeletionUndoResponse> {
    return this.client.delete<DeletionUndoResponse>(`/pesticides/${pesticideId}`);
  }
}
