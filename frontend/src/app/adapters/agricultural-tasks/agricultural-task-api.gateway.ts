import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';
import { AgriculturalTaskGateway } from '../../usecase/agricultural-tasks/agricultural-task-gateway';

@Injectable()
export class AgriculturalTaskApiGateway implements AgriculturalTaskGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<AgriculturalTask[]> {
    return this.client.get<AgriculturalTask[]>('/agricultural_tasks');
  }
}
