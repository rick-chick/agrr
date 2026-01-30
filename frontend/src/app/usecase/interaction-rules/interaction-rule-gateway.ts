import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

export interface InteractionRuleCreatePayload {
  rule_type: string;
  source_group: string;
  target_group: string;
  impact_ratio: number;
  is_directional: boolean;
  description: string | null;
  region: string | null;
}

export interface InteractionRuleGateway {
  list(): Observable<InteractionRule[]>;
  show(interactionRuleId: number): Observable<InteractionRule>;
  create(payload: InteractionRuleCreatePayload): Observable<InteractionRule>;
  update(interactionRuleId: number, payload: InteractionRuleCreatePayload): Observable<InteractionRule>;
  destroy(interactionRuleId: number): Observable<DeletionUndoResponse>;
}

export const INTERACTION_RULE_GATEWAY = new InjectionToken<InteractionRuleGateway>(
  'INTERACTION_RULE_GATEWAY'
);
