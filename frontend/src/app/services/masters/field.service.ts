import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { Field } from '../../models/masters/master-data';

@Injectable({ providedIn: 'root' })
export class FieldService {
  constructor(private readonly client: MastersClientService) {}

  listByFarm(farmId: number): Observable<Field[]> {
    return this.client.get<Field[]>(`/farms/${farmId}/fields`);
  }

  show(id: number): Observable<Field> {
    return this.client.get<Field>(`/fields/${id}`);
  }
}
