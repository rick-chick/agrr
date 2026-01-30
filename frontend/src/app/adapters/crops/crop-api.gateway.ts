import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Crop } from '../../domain/crops/crop';
import { CropGateway } from '../../usecase/crops/crop-gateway';

@Injectable()
export class CropApiGateway implements CropGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Crop[]> {
    return this.client.get<Crop[]>('/crops');
  }

  show(cropId: number): Observable<Crop> {
    return this.client.get<Crop>(`/crops/${cropId}`);
  }
}
