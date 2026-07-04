import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { MastersCropTaskTemplate } from '../../domain/crops/masters-crop-task-template';
import {
  CropTaskTemplateCreatePayload,
  CropTaskTemplateGateway
} from '../../usecase/crops/crop-task-template-gateway';

@Injectable()
export class CropTaskTemplateApiGateway implements CropTaskTemplateGateway {
  constructor(private readonly client: MastersClientService) {}

  list(cropId: number): Observable<MastersCropTaskTemplate[]> {
    return this.client.get<MastersCropTaskTemplate[]>(`/crops/${cropId}/agricultural_tasks`);
  }

  create(cropId: number, payload: CropTaskTemplateCreatePayload): Observable<MastersCropTaskTemplate> {
    return this.client.post<MastersCropTaskTemplate>(`/crops/${cropId}/agricultural_tasks`, payload);
  }

  destroy(cropId: number, templateId: number): Observable<void> {
    return this.client.delete<void>(`/crops/${cropId}/agricultural_tasks/${templateId}`);
  }
}
