import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';
import { InteractionRuleGateway } from '../../usecase/interaction-rules/interaction-rule-gateway';

@Injectable()
export class InteractionRuleApiGateway implements InteractionRuleGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<InteractionRule[]> {
    return this.client.get<InteractionRule[]>('/interaction_rules');
  }
}
