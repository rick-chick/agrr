import { InjectionToken } from '@angular/core';
import { SavePublicPlanSuccessDto } from './save-public-plan.dtos';

export interface SavePublicPlanOutputPort {
  present(dto: SavePublicPlanSuccessDto): void;
  onError(dto: { message: string }): void;
}

export const SAVE_PUBLIC_PLAN_OUTPUT_PORT = new InjectionToken<SavePublicPlanOutputPort>('SAVE_PUBLIC_PLAN_OUTPUT_PORT');