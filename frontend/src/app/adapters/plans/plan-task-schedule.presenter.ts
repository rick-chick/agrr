import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from '../../components/plans/plan-task-schedule.view';
import { LoadPlanTaskScheduleOutputPort } from '../../usecase/plans/load-plan-task-schedule.output-port';
import { PlanTaskScheduleDataDto } from '../../usecase/plans/load-plan-task-schedule.dtos';
import { RegenerateTaskScheduleOutputPort } from '../../usecase/plans/regenerate-task-schedule.output-port';
import {
  SubscribeTaskScheduleSyncOutputPort
} from '../../usecase/plans/subscribe-task-schedule-sync.output-port';
import { TaskScheduleSyncMessageDto } from '../../usecase/plans/subscribe-task-schedule-sync.dtos';
import { buildPlanTaskScheduleMonthGroupsFromRows } from '../../domain/work-schedule/build-plan-task-schedule-month-groups';
import { flattenPlanTaskSchedule } from '../../domain/work-schedule/flatten-plan-task-schedule';
import { buildPlanTaskScheduleFieldFilterOptions, filterPlanTaskScheduleRows } from '../../domain/work-schedule/filter-cross-farm-schedule';
import { resolvePlanTaskScheduleDisplayStatus } from '../../domain/work-schedule/resolve-plan-task-schedule-display-status';
import type {
  PlanTaskScheduleMonthGroupView,
  PlanTaskScheduleRowView
} from '../../components/plans/plan-task-schedule.view';
import type { CrossFarmScheduleRow } from '../../domain/work-schedule/cross-farm-schedule-row';
import type { CrossFarmScheduleMonthGroup } from '../../domain/work-schedule/group-cross-farm-schedule-by-month';
import { localTodayIso } from '../../core/local-today';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { mapTaskScheduleResponseToDomain } from './map-task-schedule-response-to-domain';
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

type DerivedViewFields = Pick<
  PlanTaskScheduleViewState,
  | 'monthGroups'
  | 'unscheduledRows'
  | 'fieldFilterOptions'
  | 'cropIdsForBanner'
  | 'cropNamesForBanner'
  | 'filteredFieldCount'
  | 'filteredTaskCount'
  | 'regenerateRequiresConfirm'
>;

const emptyDerivedFields: DerivedViewFields = {
  monthGroups: [],
  unscheduledRows: [],
  fieldFilterOptions: [],
  cropIdsForBanner: [],
  cropNamesForBanner: {},
  filteredFieldCount: 0,
  filteredTaskCount: 0,
  regenerateRequiresConfirm: false
};

@Injectable()
export class PlanTaskSchedulePresenter
  implements
    LoadPlanTaskScheduleOutputPort,
    RegenerateTaskScheduleOutputPort,
    SubscribeTaskScheduleSyncOutputPort
{
  private view: PlanTaskScheduleView | null = null;
  private syncLifecycle: TaskScheduleSyncLifecycleState = initialTaskScheduleSyncLifecycleState();

  setView(view: PlanTaskScheduleView): void {
    this.view = view;
  }

  beginScheduleLoad(): number {
    const result = beginScheduleLoad(this.syncLifecycle);
    this.syncLifecycle = result.lifecycle;
    return result.generation;
  }

  applyClientFilters(
    fromDate: string,
    fieldFilterId: number | null,
    fieldCultivationFilterId: number | null = null
  ): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const current = this.view.control;
    const derived = this.computeDerivedFields(
      current.schedule,
      fromDate,
      fieldFilterId,
      fieldCultivationFilterId
    );
    this.view.control = {
      ...current,
      fromDate,
      fieldFilterId,
      fieldCultivationFilterId,
      ...derived
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

  present(dto: PlanTaskScheduleDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (
      dto.loadGeneration != null &&
      isStaleScheduleLoad(this.syncLifecycle, dto.loadGeneration)
    ) {
      return;
    }
    const current = this.view.control;
    const fromDate = current.fromDate || localTodayIso();
    const fieldFilterId = current.fieldFilterId ?? null;
    const fieldCultivationFilterId = current.fieldCultivationFilterId ?? null;
    const loadResult = finishTaskScheduleLoad(
      this.syncLifecycle,
      dto.schedule.plan.task_schedule_sync_state
    );
    this.syncLifecycle = loadResult.lifecycle;
    let schedule = dto.schedule;
    if (loadResult.pendingMerge) {
      schedule = {
        ...schedule,
        plan: mergePlanWithSyncMessage(schedule.plan, loadResult.pendingMerge)
      };
    }
    const derived = this.computeDerivedFields(
      schedule,
      fromDate,
      fieldFilterId,
      fieldCultivationFilterId
    );
    this.view.control = {
      ...current,
      loading: false,
      error: null,
      schedule,
      regenerating: loadResult.regenerating,
      regenerateError: null,
      pendingSyncToastKey: loadResult.toastI18nKey,
      syncReloadNonce: loadResult.requestReload
        ? current.syncReloadNonce + 1
        : current.syncReloadNonce,
      fromDate,
      fieldFilterId,
      fieldCultivationFilterId,
      ...derived
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
      regenerateError: null,
      ...emptyDerivedFields
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
    const applied = this.applyTaskScheduleSync(message);
    if (!applied.schedule) {
      this.view.control = {
        ...this.view.control,
        ...applied
      };
      return;
    }

    const current = this.view.control;
    const derived = this.computeDerivedFields(
      applied.schedule,
      current.fromDate,
      current.fieldFilterId,
      current.fieldCultivationFilterId
    );
    this.view.control = {
      ...current,
      ...applied,
      ...derived
    };
  }

  private applyTaskScheduleSync(message: TaskScheduleSyncMessageDto): Partial<PlanTaskScheduleViewState> & {
    schedule?: TaskScheduleResponse;
  } {
    if (!this.view) throw new Error('Presenter: view not set');
    const current = this.view.control;
    const result = applyTaskScheduleSyncMessage({
      lifecycle: this.syncLifecycle,
      message,
      entityLoaded: current.schedule != null,
      currentSyncReloadNonce: current.syncReloadNonce
    });
    this.syncLifecycle = result.lifecycle;

    if (!result.appliedToEntity || !current.schedule) {
      return {
        regenerating: result.regenerating,
        pendingSyncToastKey: result.pendingSyncToastKey,
        syncReloadNonce: result.syncReloadNonce
      };
    }

    const nextSchedule = {
      ...current.schedule,
      plan: mergePlanWithSyncMessage(current.schedule.plan, result.message)
    };
    return {
      schedule: nextSchedule,
      regenerating: result.regenerating,
      pendingSyncToastKey: result.pendingSyncToastKey,
      syncReloadNonce: result.syncReloadNonce
    };
  }

  private computeDerivedFields(
    schedule: TaskScheduleResponse | null,
    fromDate: string,
    fieldFilterId: number | null,
    fieldCultivationFilterId: number | null
  ): DerivedViewFields {
    if (!schedule) {
      return emptyDerivedFields;
    }

    const banner = mergeCropBannerContext(schedule.fields, schedule.plan.remediation_crops);
    const snapshot = mapTaskScheduleResponseToDomain(schedule);
    const rows = flattenPlanTaskSchedule(snapshot.plan, snapshot.fields);
    const scheduledRows = rows.filter(
      (row) => row.item.scheduled_date != null && row.item.scheduled_date !== ''
    );
    const unscheduledRows = rows.filter(
      (row) => row.item.scheduled_date == null || row.item.scheduled_date === ''
    );
    const monthGroups = enrichPlanTaskScheduleMonthGroups(
      buildPlanTaskScheduleMonthGroupsFromRows(
        scheduledRows,
        fieldFilterId,
        fieldCultivationFilterId,
        fromDate
      )
    );
    const filteredUnscheduledRows = enrichPlanTaskScheduleUnscheduledRows(
      filterPlanTaskScheduleRows(unscheduledRows, fieldFilterId, fieldCultivationFilterId)
    );
    const { filteredFieldCount, filteredTaskCount } = countFilteredScheduleRows(
      monthGroups,
      filteredUnscheduledRows
    );

    return {
      monthGroups,
      unscheduledRows: filteredUnscheduledRows,
      fieldFilterOptions: buildPlanTaskScheduleFieldFilterOptions(rows),
      cropIdsForBanner: banner.cropIds,
      cropNamesForBanner: banner.cropNames,
      filteredFieldCount,
      filteredTaskCount,
      regenerateRequiresConfirm: countScheduleTasks(schedule) > 0
    };
  }
}

function enrichPlanTaskScheduleUnscheduledRows(
  rows: ReadonlyArray<CrossFarmScheduleRow>
): PlanTaskScheduleRowView[] {
  return rows.map(
    (row): PlanTaskScheduleRowView => ({
      ...row,
      displayStatus: resolvePlanTaskScheduleDisplayStatus(row.item)
    })
  );
}

function enrichPlanTaskScheduleMonthGroups(
  monthGroups: ReadonlyArray<CrossFarmScheduleMonthGroup>
): PlanTaskScheduleMonthGroupView[] {
  return monthGroups.map((group) => ({
    monthKey: group.monthKey,
    rows: group.rows.map(
      (row): PlanTaskScheduleRowView => ({
        ...row,
        displayStatus: resolvePlanTaskScheduleDisplayStatus(row.item)
      })
    )
  }));
}

function countFilteredScheduleRows(
  monthGroups: ReadonlyArray<PlanTaskScheduleMonthGroupView>,
  unscheduledRows: ReadonlyArray<PlanTaskScheduleRowView>
): {
  filteredFieldCount: number;
  filteredTaskCount: number;
} {
  const fieldIds = new Set<number>();
  let filteredTaskCount = 0;

  for (const group of monthGroups) {
    for (const row of group.rows) {
      fieldIds.add(row.fieldId);
      filteredTaskCount += 1;
    }
  }

  for (const row of unscheduledRows) {
    fieldIds.add(row.fieldId);
    filteredTaskCount += 1;
  }

  return {
    filteredFieldCount: fieldIds.size,
    filteredTaskCount
  };
}

function countScheduleTasks(schedule: TaskScheduleResponse): number {
  return schedule.fields.reduce(
    (sum, field) =>
      sum +
      field.schedules.general.length +
      field.schedules.fertilizer.length +
      field.schedules.unscheduled.length,
    0
  );
}
