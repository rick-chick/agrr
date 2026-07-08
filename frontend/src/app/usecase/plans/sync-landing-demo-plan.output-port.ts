import { InjectionToken } from '@angular/core';
import {
  SyncLandingDemoPlanErrorDto,
  SyncLandingDemoPlanLoadedDto
} from './sync-landing-demo-plan.dtos';

export interface SyncLandingDemoPlanOutputPort {
  onDemoPlanLoaded(dto: SyncLandingDemoPlanLoadedDto): void;
  onLoadError(dto: SyncLandingDemoPlanErrorDto): void;
}

export const SYNC_LANDING_DEMO_PLAN_OUTPUT_PORT = new InjectionToken<SyncLandingDemoPlanOutputPort>(
  'SYNC_LANDING_DEMO_PLAN_OUTPUT_PORT'
);
