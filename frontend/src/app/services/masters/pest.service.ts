import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { Pest } from '../../models/masters/master-data';
export type { Pest };

@Injectable({ providedIn: 'root' })
export class PestService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Pest[]> {
    return this.client.get<Pest[]>('/pests');
  }
}
