import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { GANTT_PLAN_GATEWAY, GanttPlanGateway } from './gantt-plan-gateway';
import { ApplyWeatherRescheduleProposalInputDto } from './apply-weather-reschedule-proposal.dtos';
import { ApplyWeatherRescheduleProposalInputPort } from './apply-weather-reschedule-proposal.input-port';
import {
  APPLY_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT,
  ApplyWeatherRescheduleProposalOutputPort
} from './apply-weather-reschedule-proposal.output-port';

@Injectable()
export class ApplyWeatherRescheduleProposalUseCase
  implements ApplyWeatherRescheduleProposalInputPort
{
  constructor(
    @Inject(APPLY_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT)
    private readonly outputPort: ApplyWeatherRescheduleProposalOutputPort,
    @Inject(GANTT_PLAN_GATEWAY) private readonly ganttGateway: GanttPlanGateway
  ) {}

  execute(dto: ApplyWeatherRescheduleProposalInputDto): void {
    this.ganttGateway
      .adjustPlanMoves({
        planType: dto.planType,
        planId: dto.planId,
        moves: dto.moves
      })
      .subscribe({
        next: (result) => {
          if (!result.success) {
            this.outputPort.onError({ message: result.message ?? 'plans.errors.adjust_failed' });
            return;
          }
          this.ganttGateway.loadPlanData(dto.planType, dto.planId).subscribe({
            next: (planData) => {
              if (!planData) {
                this.outputPort.onError({ message: 'plans.errors.load_failed' });
                return;
              }
              this.outputPort.present({ planData });
            },
            error: (err: unknown) =>
              this.outputPort.onError({ message: apiErrorI18nKey(err) })
          });
        },
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
