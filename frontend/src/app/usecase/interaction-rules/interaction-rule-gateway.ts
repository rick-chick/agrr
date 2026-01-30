import { InjectionToken } from '@angular/core';
import { Observable } from 'rxjs';
import { InteractionRule } from '../../domain/interaction-rules/interaction-rule';

export interface InteractionRuleGateway {
  list(): Observable<InteractionRule[]>;
}

export const INTERACTION_RULE_GATEWAY = new InjectionToken<InteractionRuleGateway>(
  'INTERACTION_RULE_GATEWAY'
);
