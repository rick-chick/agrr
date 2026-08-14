import { Injectable } from '@angular/core';
import { PlanWorkView, PlanWorkViewState } from '../../components/plans/plan-work.view';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
import {
  CreateWorkRecordSuccessDto,
  CreateWorkRecordValidationErrorDto
} from '../../usecase/plans/create-work-record.dtos';
import { CreateWorkRecordOutputPort } from '../../usecase/plans/create-work-record.output-port';
import { LoadWorkDayListDataDto, WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { LoadWorkDayListOutputPort } from '../../usecase/plans/load-work-day-list.output-port';
import { SkipTaskScheduleItemOutputPort } from '../../usecase/plans/skip-task-schedule-item.output-port';
import { UpdateTaskScheduleItemOutputPort } from '../../usecase/plans/update-task-schedule-item.output-port';
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
  beginScheduleLoad,
  finishTaskScheduleLoad,
  initialTaskScheduleSyncLifecycleState,
  isStaleScheduleLoad,
  markRegeneratePostInFlight,
  mergePlanWithSyncMessage,
  taskScheduleSyncMessageFromRegenerateResponse,
  type TaskScheduleSyncLifecycleState
} from '../../usecase/plans/task-schedule-sync-lifecycle';
import { RegenerateTaskScheduleResponseDto } from '../../usecase/plans/regenerate-task-schedule-response.dtos';
import { buildWorkRecordSaveToast, WorkRecordSaveToastContext } from '../../domain/plans/work-record-save-toast';
import {
  applyPlanSaveImpactSummary,
  beginPlanSaveImpactLoad,
  emptyPlanSaveImpactViewFields,
  PendingSaveImpactRequest,
  planSaveImpactErrorFields
} from './plan-save-impact.presenter.helpers';
import { mapWorkRecordSaveToastToPendingRequest } from './work-record-save-toast.presenter.helpers';
import { WorkRecordSheetSavedEvent } from '../../components/plans/work-record-sheet.view';
import { PlanVsActualSummaryDataDto } from '../../usecase/plans/load-plan-vs-actual-summary.output-port';
import { buildPlanWorkVarianceSummaryStats } from '../../domain/plans/build-plan-work-variance-summary-stats';

const emptyCropBannerFields: Pick<PlanWorkViewState, 'cropIdsForBanner' | 'cropNamesForBanner'> = {
  cropIdsForBanner: [],
  cropNamesForBanner: {}
};

const emptyPageVarianceFields: Pick<
  PlanWorkViewState,
  'varianceSummaryLoading' | 'varianceSummaryError' | 'varianceSummaryStats' | 'actionRequiredItems'
> = {
  varianceSummaryLoading: true,
  varianceSummaryError: null,
  varianceSummaryStats: null,
  actionRequiredItems: []
};

@Injectable()
export class PlanWorkPresenter
  implements
    LoadWorkDayListOutputPort,
    SkipTaskScheduleItemOutputPort,
    UpdateTaskScheduleItemOutputPort,
    CreateWorkRecordOutputPort,
    RegenerateTaskScheduleOutputPort,
    SubscribeTaskScheduleSyncOutputPort
{
  private view: PlanWorkView | null = null;
  private syncLifecycle: TaskScheduleSyncLifecycleState = initialTaskScheduleSyncLifecycleState();
  private pendingSaveImpactRequest: PendingSaveImpactRequest | null = null;
  private saveImpactLoadGeneration = 0;
  private pageVarianceLoadGeneration = 0;

  setView(view: PlanWorkView): void {
    this.view = view;
  }

  beginScheduleLoad(): number {
    const result = beginScheduleLoad(this.syncLifecycle);
    this.syncLifecycle = result.lifecycle;
    return result.generation;
  }

  beginPageVarianceLoad(): number {
    this.pageVarianceLoadGeneration += 1;
    return this.pageVarianceLoadGeneration;
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
    if (
      dto.loadGeneration != null &&
      isStaleScheduleLoad(this.syncLifecycle, dto.loadGeneration)
    ) {
      return;
    }
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
      pendingRecordSavedToast: null,
      pendingRecordSavedEvent: null,
      ...emptyPlanSaveImpactViewFields,
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
      ...emptyCropBannerFields,
      ...emptyPageVarianceFields
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
    const itemId = this.view.control.completingItemId;
    const row = itemId != null ? this.findRowByItemId(itemId) : null;
    const planId = this.view.control.plan?.id;
    const saveContext =
      row && planId
        ? {
            planId,
            fieldCultivationId: row.item.field_cultivation_id,
            taskScheduleItemId: row.item.item_id,
            gddTrigger: row.item.gdd_trigger ?? row.item.details?.gdd?.trigger ?? null
          }
        : null;

    this.view.control = {
      ...this.view.control,
      completingItemId: null,
      error: null,
      pendingRecordSavedToast: mapWorkRecordSaveToastToPendingRequest(
        buildWorkRecordSaveToast(
          dto.workRecord,
          'create-from-item',
          saveContext
        )
      ),
      pendingRecordSavedEvent: {
        workRecord: dto.workRecord,
        mode: 'create-from-item',
        saveToastContext: saveContext
      }
    };
  }

  queueSaveImpactAfterSave(event: WorkRecordSheetSavedEvent): number {
    if (!this.view || event.mode === 'edit') {
      return 0;
    }
    const context = event.saveToastContext ?? null;
    const fields = this.beginSaveImpactLoadFields(event, context);
    this.pageVarianceLoadGeneration = this.saveImpactLoadGeneration;
    this.view.control = {
      ...this.view.control,
      ...fields,
      varianceSummaryLoading: true,
      varianceSummaryError: null
    };
    return this.saveImpactLoadGeneration;
  }

  presentSaveImpactSummary(dto: PlanVsActualSummaryDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const applied = applyPlanSaveImpactSummary(
      this.pendingSaveImpactRequest,
      dto.loadGeneration,
      this.saveImpactLoadGeneration,
      dto
    );
    if (applied) {
      this.pendingSaveImpactRequest = applied.pending;
      this.view.control = {
        ...this.view.control,
        ...applied.fields
      };
    }
    this.applyPageVarianceSummary(dto);
  }

  onSaveImpactError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.pendingSaveImpactRequest = null;
    this.view.control = {
      ...this.view.control,
      ...planSaveImpactErrorFields(dto.message)
    };
    this.onPageVarianceError(dto);
  }

  onPageVarianceError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (!this.view.control.varianceSummaryLoading) {
      return;
    }
    this.view.control = {
      ...this.view.control,
      varianceSummaryLoading: false,
      varianceSummaryError: dto.message,
      varianceSummaryStats: null,
      actionRequiredItems: []
    };
  }

  private applyPageVarianceSummary(dto: PlanVsActualSummaryDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.loadGeneration !== this.pageVarianceLoadGeneration) {
      return;
    }
    const actionRequiredItems = dto.summary.action_required_items ?? [];
    this.view.control = {
      ...this.view.control,
      varianceSummaryLoading: false,
      varianceSummaryError: null,
      varianceSummaryStats: buildPlanWorkVarianceSummaryStats(dto.summary),
      actionRequiredItems
    };
  }

  dismissSaveImpact(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      ...emptyPlanSaveImpactViewFields
    };
  }

  private beginSaveImpactLoadFields(
    event: WorkRecordSheetSavedEvent,
    context: WorkRecordSaveToastContext | null = event.saveToastContext ?? null
  ): ReturnType<typeof beginPlanSaveImpactLoad>['fields'] {
    this.saveImpactLoadGeneration += 1;
    this.pendingSaveImpactRequest = { event, context };
    return beginPlanSaveImpactLoad(this.pendingSaveImpactRequest, this.saveImpactLoadGeneration).fields;
  }

  private findRowByItemId(itemId: number): WorkDayListRowDto | null {
    if (!this.view) {
      return null;
    }
    const rows = [
      ...this.view.control.overdue,
      ...this.view.control.today,
      ...this.view.control.upcoming
    ];
    return rows.find((row) => row.item.item_id === itemId) ?? null;
  }
}
