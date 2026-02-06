import { InjectionToken } from '@angular/core';

export interface ResetPublicPlanCreationStateOutputPort {
  // Empty - reset is a side effect, no output needed
}

export const RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT = new InjectionToken<ResetPublicPlanCreationStateOutputPort>(
  'RESET_PUBLIC_PLAN_CREATION_STATE_OUTPUT_PORT'
);
