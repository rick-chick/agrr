import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { AgriculturalTask } from '../../models/masters/master-data';
export type { AgriculturalTask };

@Injectable({ providedIn: 'root' })
export class AgriculturalTaskService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<AgriculturalTask[]> {
    return this.client.get<AgriculturalTask[]>('/agricultural_tasks');
  }
}
