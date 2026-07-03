import { Inject, Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import {
  GanttPlanMutationCommandResult,
  GanttPlanMutationOutcome,
  ganttMutationFailure,
  ganttMutationSuccess
} from '../../domain/plans/gantt-plan-mutation';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { GANTT_PLAN_GATEWAY, GanttPlanGateway } from './gantt-plan-gateway';
import { RunGanttPlanMutationInputDto } from './run-gantt-plan-mutation.dtos';
import { RunGanttPlanMutationInputPort } from './run-gantt-plan-mutation.input-port';
import {
  RUN_GANTT_PLAN_MUTATION_OUTPUT_PORT,
  RunGanttPlanMutationOutputPort
} from './run-gantt-plan-mutation.output-port';

@Injectable()
export class RunGanttPlanMutationUseCase implements RunGanttPlanMutationInputPort {
  constructor(
    @Inject(RUN_GANTT_PLAN_MUTATION_OUTPUT_PORT) private readonly outputPort: RunGanttPlanMutationOutputPort,
    @Inject(GANTT_PLAN_GATEWAY) private readonly gateway: GanttPlanGateway
  ) {}

  execute(dto: RunGanttPlanMutationInputDto): void {
    this.resolveRequest(dto).subscribe({
      next: (outcome) =>
        this.outputPort.onMutationOutcome(outcome, {
          planId: dto.planId,
          presentation: dto.presentation
        })
    });
  }

  private resolveRequest(dto: RunGanttPlanMutationInputDto): Observable<GanttPlanMutationOutcome> {
    return this.mutationCommand$(dto).pipe(
      switchMap((commandResult) =>
        this.finalizeMutationOutcome(dto.planType, dto.planId, commandResult)
      )
    );
  }

  private mutationCommand$(dto: RunGanttPlanMutationInputDto): Observable<GanttPlanMutationCommandResult> {
    const { planType, planId, command } = dto;
    switch (command.kind) {
      case 'adjustCultivationMove':
        return this.gateway.adjustCultivationMove({
          planType,
          planId,
          cultivationId: command.cultivationId,
          toFieldId: command.toFieldId,
          newStartDate: command.newStartDate
        });
      case 'addCrop':
        return this.gateway.addCrop(planType, planId, command.payload);
      case 'removeCultivation':
        return this.gateway.removeCultivation(planType, planId, command.cultivationId);
      case 'addField':
        return this.gateway.addField(planType, planId, command.payload);
      case 'removeField':
        return this.gateway.removeField(planType, planId, command.fieldId);
    }
  }

  private finalizeMutationOutcome(
    planType: CultivationPlanContextType,
    planId: number,
    commandResult: GanttPlanMutationCommandResult
  ): Observable<GanttPlanMutationOutcome> {
    if (commandResult.success === false) {
      return of(ganttMutationFailure({ message: commandResult.message }));
    }

    return this.gateway.loadPlanData(planType, planId).pipe(
        map((data) =>
          data ? ganttMutationSuccess(data) : ganttMutationFailure({ refetchFailed: true })
        ),
        catchError(() => of(ganttMutationFailure({ refetchError: true })))
    );
  }
}
