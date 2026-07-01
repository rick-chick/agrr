import { Inject, Injectable } from '@angular/core';
import { SubscribeTaskScheduleSyncInputDto } from './subscribe-task-schedule-sync.dtos';
import { SubscribeTaskScheduleSyncInputPort } from './subscribe-task-schedule-sync.input-port';
import {
  SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT,
  SubscribeTaskScheduleSyncOutputPort
} from './subscribe-task-schedule-sync.output-port';
import { PLAN_OPTIMIZATION_GATEWAY, PlanOptimizationGateway } from './plan-optimization-gateway';

@Injectable()
export class SubscribeTaskScheduleSyncUseCase implements SubscribeTaskScheduleSyncInputPort {
  constructor(
    @Inject(SUBSCRIBE_TASK_SCHEDULE_SYNC_OUTPUT_PORT)
    private readonly outputPort: SubscribeTaskScheduleSyncOutputPort,
    @Inject(PLAN_OPTIMIZATION_GATEWAY) private readonly cableGateway: PlanOptimizationGateway
  ) {}

  execute(dto: SubscribeTaskScheduleSyncInputDto): void {
    const channel = this.cableGateway.subscribeTaskScheduleSync(dto.planId, {
      received: (message) => this.outputPort.onTaskScheduleSync(message)
    });
    dto.onSubscribed?.(channel);
  }
}
