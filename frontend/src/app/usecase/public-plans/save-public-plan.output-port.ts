import { InjectionToken } from '@angular/core';

export interface SavePublicPlanOutputPort {
  present(dto: { message: string }): void;
  onError(dto: { message: string }): void;
}

export const SAVE_PUBLIC_PLAN_OUTPUT_PORT = new InjectionToken<SavePublicPlanOutputPort>('SAVE_PUBLIC_PLAN_OUTPUT_PORT');