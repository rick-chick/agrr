import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { MastersClientService } from '../../services/masters/masters-client.service';
import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';
import { InteractionRuleGateway, InteractionRuleCreatePayload } from '../../usecase/interaction-rules/interaction-rule-gateway';

@Injectable()
export class InteractionRuleApiGateway implements InteractionRuleGateway {
  constructor(private readonly client: MastersClientService) {}

  list(): Observable<InteractionRule[]> {
    return this.client.get<InteractionRule[]>('/interaction_rules');
  }

  show(interactionRuleId: number): Observable<InteractionRule> {
    return this.client.get<InteractionRule>(`/interaction_rules/${interactionRuleId}`);
  }

  create(payload: InteractionRuleCreatePayload): Observable<InteractionRule> {
    return this.client.post<InteractionRule>('/interaction_rules', { interaction_rule: payload });
  }

  update(interactionRuleId: number, payload: InteractionRuleCreatePayload): Observable<InteractionRule> {
    return this.client.patch<InteractionRule>(`/interaction_rules/${interactionRuleId}`, { interaction_rule: payload });
  }

  destroy(interactionRuleId: number): Observable<DeletionUndoResponse> {
    return this.client.delete<DeletionUndoResponse>(`/interaction_rules/${interactionRuleId}`);
  }
}
