import { Injectable } from '@angular/core';
import { Channel } from 'actioncable';
import { OptimizationService } from '../../services/plans/optimization.service';
import { normalizeTaskScheduleSyncError } from '../../domain/plans/task-schedule-sync-error';
import { PlanOptimizationGateway } from '../../usecase/plans/plan-optimization-gateway';
import { PlanOptimizationMessageDto } from '../../usecase/plans/subscribe-plan-optimization.dtos';
import { TaskScheduleSyncMessageDto } from '../../usecase/plans/subscribe-task-schedule-sync.dtos';

@Injectable()
export class PlanOptimizationChannelGateway implements PlanOptimizationGateway {
  constructor(private readonly optimizationService: OptimizationService) {}

  subscribe(
    planId: number,
    callbacks: { received: (message: PlanOptimizationMessageDto) => void }
  ): Channel {
    return this.optimizationService.subscribe(
      'PlansOptimizationChannel',
      { cultivation_plan_id: planId },
      { received: callbacks.received }
    );
  }

  subscribeTaskScheduleSync(
    planId: number,
    callbacks: { received: (message: TaskScheduleSyncMessageDto) => void }
  ): Channel {
    return this.optimizationService.subscribe(
      'PlansOptimizationChannel',
      { cultivation_plan_id: planId },
      {
        received: (payload) => {
          const message = this.parseTaskScheduleSyncMessage(payload);
          if (message) {
            callbacks.received(message);
          }
        }
      }
    );
  }

  private parseTaskScheduleSyncMessage(
    payload: Record<string, unknown>
  ): TaskScheduleSyncMessageDto | null {
    if (payload['type'] !== 'task_schedule_sync') {
      return null;
    }
    const syncState = payload['task_schedule_sync_state'];
    if (typeof syncState !== 'string') {
      return null;
    }
    const syncError = payload['task_schedule_sync_error'];
    const syncErrorCropId = payload['task_schedule_sync_error_crop_id'];
    return {
      syncState,
      syncError:
        typeof syncError === 'string' ? normalizeTaskScheduleSyncError(syncError) : null,
      syncErrorCropId:
        typeof syncErrorCropId === 'number' && syncErrorCropId > 0 ? syncErrorCropId : null
    };
  }
}
