import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanTaskScheduleView } from '../../components/plans/plan-task-schedule.view';
import { LoadPlanTaskScheduleOutputPort } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';
import { RegenerateTaskScheduleOutputPort } from '../../usecase/plans/regenerate-task-schedule.output-port';
import {
  SubscribeTaskScheduleSyncOutputPort
} from '../../usecase/plans/subscribe-task-schedule-sync.output-port';
import { TaskScheduleSyncMessageDto } from '../../usecase/plans/subscribe-task-schedule-sync.dtos';
import {
  applySyncFieldsToPlan,
  taskScheduleSyncViewPatch
} from './task-schedule-sync-presenter.helpers';

@Injectable()
export class PlanTaskSchedulePresenter
  implements
    LoadPlanTaskScheduleOutputPort,
    RegenerateTaskScheduleOutputPort,
    SubscribeTaskScheduleSyncOutputPort
{
  private view: PlanTaskScheduleView | null = null;

  setView(view: PlanTaskScheduleView): void {
    this.view = view;
  }

  onRegenerateStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      regenerating: true,
      regenerateError: null
    };
  }

  present(dto: PlanTaskScheduleDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      schedule: dto.schedule,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      syncReloadNonce: 0
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      schedule: null,
      regenerating: false,
      regenerateError: null
    };
  }

  onRegenerateSuccess(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      regenerateError: null
    };
  }

  onRegenerateError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      regenerating: false,
      regenerateError: dto.message
    };
  }

  onTaskScheduleSync(message: TaskScheduleSyncMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const schedule = this.view.control.schedule;
    if (!schedule) {
      return;
    }

    const nextPlan = applySyncFieldsToPlan(schedule.plan, message);
    const nextSchedule = { ...schedule, plan: nextPlan };
    const patch = taskScheduleSyncViewPatch(message.syncState);
    const current = this.view.control;
    this.view.control = {
      ...current,
      schedule: nextSchedule,
      regenerating: patch.regenerating,
      pendingSyncToastKey: patch.toastI18nKey,
      syncReloadNonce: patch.requestReload
        ? current.syncReloadNonce + 1
        : current.syncReloadNonce
    };
  }
}
