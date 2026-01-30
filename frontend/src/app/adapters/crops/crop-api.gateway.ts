import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Crop } from '../../domain/crops/crop';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { CropGateway, CropCreatePayload } from '../../usecase/crops/crop-gateway';

@Injectable()
export class CropApiGateway implements CropGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Crop[]> {
    return this.client.get<Crop[]>('/crops');
  }

  show(cropId: number): Observable<Crop> {
    return this.client.get<Crop>(`/crops/${cropId}`);
  }

  create(payload: CropCreatePayload): Observable<Crop> {
    return this.client.post<Crop>('/crops', { crop: payload });
  }

  update(cropId: number, payload: CropCreatePayload): Observable<Crop> {
    return this.client.patch<Crop>(`/crops/${cropId}`, { crop: payload });
  }

  destroy(cropId: number): Observable<DeletionUndoResponse> {
    return this.client.delete<DeletionUndoResponse>(`/crops/${cropId}`);
  }
}
