import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from './masters-client.service';
import { InteractionRule } from '../../models/masters/master-data';
export type { InteractionRule };

@Injectable({ providedIn: 'root' })
export class InteractionRuleService {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<InteractionRule[]> {
    return this.client.get<InteractionRule[]>('/interaction_rules');
  }
}
