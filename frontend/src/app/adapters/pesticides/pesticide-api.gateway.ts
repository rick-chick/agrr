import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { Pesticide } from '../../domain/pesticides/pesticide';
import { PesticideGateway } from '../../usecase/pesticides/pesticide-gateway';

@Injectable()
export class PesticideApiGateway implements PesticideGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<Pesticide[]> {
    return this.client.get<Pesticide[]>('/pesticides');
  }
}
