import { SyncLandingDemoPlanInputDto } from './sync-landing-demo-plan.dtos';

export interface SyncLandingDemoPlanInputPort {
  execute(dto: SyncLandingDemoPlanInputDto): void;
}
