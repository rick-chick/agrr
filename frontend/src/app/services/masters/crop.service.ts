import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { Crop } from '../../models/masters/master-data';
export type { Crop };

@Injectable({ providedIn: 'root' })
export class CropService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Crop[]> {
    return this.client.get<Crop[]>('/crops');
  }

  show(id: number): Observable<Crop> {
    return this.client.get<Crop>(`/crops/${id}`);
  }
}
