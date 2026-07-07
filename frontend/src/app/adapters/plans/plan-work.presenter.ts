import { Injectable } from '@angular/core';
import { PlanWorkView } from '../../components/plans/plan-work.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import {
  CreateWorkRecordSuccessDto,
  CreateWorkRecordValidationErrorDto
} from '../../usecase/plans/create-work-record.dtos';
import { CreateWorkRecordOutputPort } from '../../usecase/plans/create-work-record.output-port';
import { LoadWorkDayListDataDto } from '../../usecase/plans/load-work-day-list.dtos';
import { LoadWorkDayListOutputPort } from '../../usecase/plans/load-work-day-list.output-port';
import { SkipTaskScheduleItemOutputPort } from '../../usecase/plans/skip-task-schedule-item.output-port';
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
export class PlanWorkPresenter
  implements
    LoadWorkDayListOutputPort,
    SkipTaskScheduleItemOutputPort,
    CreateWorkRecordOutputPort,
    RegenerateTaskScheduleOutputPort,
    SubscribeTaskScheduleSyncOutputPort
{
  private view: PlanWorkView | null = null;

  setView(view: PlanWorkView): void {
    this.view = view;
  }

  onSuccess(dto?: CreateWorkRecordSuccessDto): void {
    if (dto?.workRecord != null) {
      this.handleQuickCompleteSuccess(dto);
      return;
    }
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      syncReloadNonce: this.view.control.syncReloadNonce + 1
    };
  }

  onRegenerateStarted(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      regenerating: true,
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

  onTaskScheduleSync(message: TaskScheduleSyncMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const plan = this.view.control.plan;
    if (!plan) {
      return;
    }

    const nextPlan = applySyncFieldsToPlan(plan, message);
    const patch = taskScheduleSyncViewPatch(message.syncState);
    const current = this.view.control;
    this.view.control = {
      ...current,
      plan: nextPlan,
      regenerating: patch.regenerating,
      pendingSyncToastKey: patch.toastI18nKey,
      syncReloadNonce: patch.requestReload
        ? current.syncReloadNonce + 1
        : current.syncReloadNonce
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

  present(dto: LoadWorkDayListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      plan: dto.plan,
      fields: dto.fields,
      overdue: dto.overdue,
      today: dto.today,
      upcoming: dto.upcoming,
      recentAdHocRecord: dto.recentAdHocRecord,
      nextScheduled: dto.nextScheduled,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      pendingRecordSavedToastKey: null,
      pendingRecordSavedEvent: null,
      pendingQuickCompleteValidation: null,
      syncReloadNonce: 0
    };
  }

  onValidationError(dto: CreateWorkRecordValidationErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const itemId = this.view.control.completingItemId;
    if (itemId == null) return;
    this.view.control = {
      ...this.view.control,
      completingItemId: null,
      pendingQuickCompleteValidation: { itemId, fieldErrors: dto.fieldErrors }
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (this.view.control.completingItemId != null) {
      this.view.control = {
        ...this.view.control,
        completingItemId: null,
        error: dto.message
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      plan: null,
      fields: [],
      overdue: [],
      today: [],
      upcoming: [],
      nextScheduled: null,
      regenerating: false,
      regenerateError: null
    };
  }

  private handleQuickCompleteSuccess(dto: CreateWorkRecordSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      completingItemId: null,
      error: null,
      pendingRecordSavedToastKey: 'plans.work.toast.record_saved',
      pendingRecordSavedEvent: {
        workRecord: dto.workRecord,
        mode: 'create-from-item'
      }
    };
  }
}
