import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pest } from '../../domain/pests/pest';
import { PestGateway } from '../../usecase/pests/pest-gateway';

@Injectable()
export class PestApiGateway implements PestGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Pest[]> {
    return this.client.get<Pest[]>('/pests');
  }
}
