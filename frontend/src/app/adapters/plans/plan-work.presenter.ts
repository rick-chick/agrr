import { Injectable } from '@angular/core';
import { PlanWorkView, PlanWorkViewState } from '../../components/plans/plan-work.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
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
  mergeCropBannerContext
} from './task-schedule-sync-presenter.helpers';
import {
  applyTaskScheduleSyncMessage,
  finishTaskScheduleLoad,
  initialTaskScheduleSyncLifecycleState,
  markRegeneratePostInFlight,
  mergePlanWithSyncMessage,
  taskScheduleSyncMessageFromRegenerateResponse,
  type TaskScheduleSyncLifecycleState
} from '../../usecase/plans/task-schedule-sync-lifecycle';
import { RegenerateTaskScheduleResponseDto } from '../../usecase/plans/regenerate-task-schedule-response.dtos';

const emptyCropBannerFields: Pick<PlanWorkViewState, 'cropIdsForBanner' | 'cropNamesForBanner'> = {
  cropIdsForBanner: [],
  cropNamesForBanner: {}
};

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
  private syncLifecycle: TaskScheduleSyncLifecycleState = initialTaskScheduleSyncLifecycleState();

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
    this.syncLifecycle = markRegeneratePostInFlight(this.syncLifecycle);
    this.view.control = {
      ...this.view.control,
      regenerating: true,
      regenerateError: null
    };
  }

  onRegenerateSuccess(dto: RegenerateTaskScheduleResponseDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const message = taskScheduleSyncMessageFromRegenerateResponse(dto);
    const applied = this.applyTaskScheduleSync(message);
    this.view.control = {
      ...this.view.control,
      regenerateError: null,
      ...applied
    };
  }

  onTaskScheduleSync(message: TaskScheduleSyncMessageDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const applied = this.applyTaskScheduleSync(message);
    this.view.control = {
      ...this.view.control,
      ...applied
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
    const loadResult = finishTaskScheduleLoad(
      this.syncLifecycle,
      dto.plan.task_schedule_sync_state
    );
    this.syncLifecycle = loadResult.lifecycle;
    let plan = dto.plan;
    if (loadResult.pendingMerge) {
      plan = mergePlanWithSyncMessage(plan, loadResult.pendingMerge);
    }
    const cropBanner = this.computeCropBannerFields(dto.fields, plan);
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      plan,
      fields: dto.fields,
      overdue: dto.overdue,
      today: dto.today,
      upcoming: dto.upcoming,
      recentAdHocRecord: dto.recentAdHocRecord,
      nextScheduled: dto.nextScheduled,
      regenerating: loadResult.regenerating,
      regenerateError: null,
      pendingSyncToastKey: loadResult.toastI18nKey,
      pendingRecordSavedToastKey: null,
      pendingRecordSavedEvent: null,
      pendingQuickCompleteValidation: null,
      syncReloadNonce: loadResult.requestReload
        ? this.view.control.syncReloadNonce + 1
        : this.view.control.syncReloadNonce,
      ...cropBanner
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
      regenerateError: null,
      ...emptyCropBannerFields
    };
  }

  private computeCropBannerFields(
    fields: FieldSchedule[],
    plan: PlanInfo | null
  ): Pick<PlanWorkViewState, 'cropIdsForBanner' | 'cropNamesForBanner'> {
    const banner = mergeCropBannerContext(fields, plan?.remediation_crops);
    return {
      cropIdsForBanner: banner.cropIds,
      cropNamesForBanner: banner.cropNames
    };
  }

  private applyTaskScheduleSync(message: TaskScheduleSyncMessageDto): Partial<PlanWorkViewState> {
    if (!this.view) throw new Error('Presenter: view not set');
    const current = this.view.control;
    const result = applyTaskScheduleSyncMessage({
      lifecycle: this.syncLifecycle,
      message,
      entityLoaded: current.plan != null,
      currentSyncReloadNonce: current.syncReloadNonce
    });
    this.syncLifecycle = result.lifecycle;

    if (!result.appliedToEntity || !current.plan) {
      return {
        regenerating: result.regenerating,
        pendingSyncToastKey: result.pendingSyncToastKey,
        syncReloadNonce: result.syncReloadNonce
      };
    }

    const nextPlan = mergePlanWithSyncMessage(current.plan, result.message);
    const cropBanner = this.computeCropBannerFields(current.fields, nextPlan);
    return {
      plan: nextPlan,
      regenerating: result.regenerating,
      pendingSyncToastKey: result.pendingSyncToastKey,
      syncReloadNonce: result.syncReloadNonce,
      ...cropBanner
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
