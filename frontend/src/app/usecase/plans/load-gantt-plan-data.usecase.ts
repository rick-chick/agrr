import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { GANTT_PLAN_GATEWAY, GanttPlanGateway } from './gantt-plan-gateway';
import { LoadGanttPlanDataInputDto } from './load-gantt-plan-data.dtos';
import { LoadGanttPlanDataInputPort } from './load-gantt-plan-data.input-port';
import {
  LOAD_GANTT_PLAN_DATA_OUTPUT_PORT,
  LoadGanttPlanDataOutputPort
} from './load-gantt-plan-data.output-port';

@Injectable()
export class LoadGanttPlanDataUseCase implements LoadGanttPlanDataInputPort {
  constructor(
    @Inject(LOAD_GANTT_PLAN_DATA_OUTPUT_PORT) private readonly outputPort: LoadGanttPlanDataOutputPort,
    @Inject(GANTT_PLAN_GATEWAY) private readonly gateway: GanttPlanGateway
  ) {}

  execute(dto: LoadGanttPlanDataInputDto): void {
    this.gateway.loadPlanData(dto.planType, dto.planId).subscribe({
      next: (planData) => {
        if (planData) {
          this.outputPort.onPlanDataLoaded({ data: planData, purpose: dto.purpose });
        } else {
          this.outputPort.onPlanDataEmpty({ purpose: dto.purpose });
        }
      },
      error: (error: unknown) =>
        this.outputPort.onLoadError({
          message: apiErrorI18nKey(error),
          purpose: dto.purpose
        })
    });
  }
}
