import { Inject, Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { LoadPlanTaskScheduleInputDto } from './load-plan-task-schedule.dtos';
import { LoadPlanTaskScheduleInputPort } from './load-plan-task-schedule.input-port';
import {
  LoadPlanTaskScheduleOutputPort,
  LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT
} from './load-plan-task-schedule.output-port';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';

@Injectable()
export class LoadPlanTaskScheduleUseCase implements LoadPlanTaskScheduleInputPort {
  constructor(
    @Inject(LOAD_PLAN_TASK_SCHEDULE_OUTPUT_PORT) private readonly outputPort: LoadPlanTaskScheduleOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadPlanTaskScheduleInputDto): void {
    this.planGateway.getTaskSchedule(dto.planId).subscribe({
      next: (schedule) => this.outputPort.present({ schedule }),
      error: (err: Error) =>
        this.outputPort.onError({ message: err?.message ?? 'Unknown error' })
    });
  }
}
