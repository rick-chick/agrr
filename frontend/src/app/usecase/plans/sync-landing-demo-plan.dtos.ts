import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { LandingDemoLabels } from '../../domain/plans/landing-demo-i18n.keys';

export interface SyncLandingDemoPlanInputDto {
  labels: LandingDemoLabels;
}

export interface SyncLandingDemoPlanLoadedDto {
  data: CultivationPlanData;
}

export interface SyncLandingDemoPlanErrorDto {
  message?: string;
}
