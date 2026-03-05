import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pest } from '../../domain/pests/pest';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { PestGateway, PestCreatePayload } from '../../usecase/pests/pest-gateway';

@Injectable()
export class PestApiGateway implements PestGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Pest[]> {
    return this.client.get<Pest[]>('/pests');
  }

  show(pestId: number): Observable<Pest> {
    return this.client.get<Pest>(`/pests/${pestId}`);
  }

  create(payload: PestCreatePayload): Observable<Pest> {
    return this.client.post<Pest>('/pests', { pest: payload });
  }

  update(pestId: number, payload: PestCreatePayload): Observable<Pest> {
    return this.client.patch<Pest>(`/pests/${pestId}`, { pest: payload });
  }

  destroy(pestId: number) {
    return this.client
      .delete<DeletionUndoResponse>(`/pests/${pestId}`)
      .pipe(map((r) => ({ undo: r })));
  }
}
