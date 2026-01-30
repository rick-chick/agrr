import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { Pesticide } from '../../models/masters/master-data';
export type { Pesticide };

@Injectable({ providedIn: 'root' })
export class PesticideService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Pesticide[]> {
    return this.client.get<Pesticide[]>('/pesticides');
  }
}
