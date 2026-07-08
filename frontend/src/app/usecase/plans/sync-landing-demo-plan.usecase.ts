import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { GANTT_PLAN_GATEWAY, GanttPlanGateway } from './gantt-plan-gateway';
import { SyncLandingDemoPlanInputDto } from './sync-landing-demo-plan.dtos';
import { SyncLandingDemoPlanInputPort } from './sync-landing-demo-plan.input-port';
import {
  SYNC_LANDING_DEMO_PLAN_OUTPUT_PORT,
  SyncLandingDemoPlanOutputPort
} from './sync-landing-demo-plan.output-port';

@Injectable()
export class SyncLandingDemoPlanUseCase implements SyncLandingDemoPlanInputPort {
  constructor(
    @Inject(SYNC_LANDING_DEMO_PLAN_OUTPUT_PORT)
    private readonly outputPort: SyncLandingDemoPlanOutputPort,
    @Inject(GANTT_PLAN_GATEWAY) private readonly gateway: GanttPlanGateway
  ) {}

  execute(dto: SyncLandingDemoPlanInputDto): void {
    this.gateway.syncLandingDemoPlan(dto.labels).subscribe({
      next: (data) => this.outputPort.onDemoPlanLoaded({ data }),
      error: (error: unknown) =>
        this.outputPort.onLoadError({
          message: apiErrorI18nKey(error)
        })
    });
  }
}
