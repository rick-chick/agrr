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
import { buildPlanTaskScheduleFieldFilterOptions } from '../../domain/work-schedule/filter-cross-farm-schedule';
import { resolvePlanTaskScheduleDisplayStatus } from '../../domain/work-schedule/resolve-plan-task-schedule-display-status';
import type {
  PlanTaskScheduleMonthGroupView,
  PlanTaskScheduleRowView
} from '../../components/plans/plan-task-schedule.view';
import type { CrossFarmScheduleMonthGroup } from '../../domain/work-schedule/group-cross-farm-schedule-by-month';
import { localTodayIso } from '../../core/local-today';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { mapTaskScheduleResponseToDomain } from './map-task-schedule-response-to-domain';
import {
  applySyncFieldsToPlan,
  mergeCropBannerContext,
  taskScheduleSyncViewPatch
} from './task-schedule-sync-presenter.helpers';

type DerivedViewFields = Pick<
  PlanTaskScheduleViewState,
  | 'monthGroups'
  | 'fieldFilterOptions'
  | 'cropIdsForBanner'
  | 'cropNamesForBanner'
  | 'filteredFieldCount'
  | 'filteredTaskCount'
  | 'regenerateRequiresConfirm'
>;

const emptyDerivedFields: DerivedViewFields = {
  monthGroups: [],
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

  setView(view: PlanTaskScheduleView): void {
    this.view = view;
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
    this.view.control = {
      ...this.view.control,
      regenerating: true,
      regenerateError: null
    };
  }

  present(dto: PlanTaskScheduleDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const current = this.view.control;
    const fromDate = current.fromDate || localTodayIso();
    const fieldFilterId = current.fieldFilterId ?? null;
    const fieldCultivationFilterId = current.fieldCultivationFilterId ?? null;
    const derived = this.computeDerivedFields(
      dto.schedule,
      fromDate,
      fieldFilterId,
      fieldCultivationFilterId
    );
    this.view.control = {
      ...current,
      loading: false,
      error: null,
      schedule: dto.schedule,
      regenerating: false,
      regenerateError: null,
      pendingSyncToastKey: null,
      syncReloadNonce: 0,
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
    const derived = this.computeDerivedFields(
      nextSchedule,
      current.fromDate,
      current.fieldFilterId,
      current.fieldCultivationFilterId
    );
    this.view.control = {
      ...current,
      schedule: nextSchedule,
      regenerating: patch.regenerating,
      pendingSyncToastKey: patch.toastI18nKey,
      syncReloadNonce: patch.requestReload
        ? current.syncReloadNonce + 1
        : current.syncReloadNonce,
      ...derived
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
    const monthGroups = enrichPlanTaskScheduleMonthGroups(
      buildPlanTaskScheduleMonthGroupsFromRows(
        rows,
        fieldFilterId,
        fieldCultivationFilterId,
        fromDate
      )
    );
    const { filteredFieldCount, filteredTaskCount } = countFilteredScheduleRows(monthGroups);

    return {
      monthGroups,
      fieldFilterOptions: buildPlanTaskScheduleFieldFilterOptions(rows),
      cropIdsForBanner: banner.cropIds,
      cropNamesForBanner: banner.cropNames,
      filteredFieldCount,
      filteredTaskCount,
      regenerateRequiresConfirm: countScheduleTasks(schedule) > 0
    };
  }
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

function countFilteredScheduleRows(monthGroups: ReadonlyArray<PlanTaskScheduleMonthGroupView>): {
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

  return {
    filteredFieldCount: fieldIds.size,
    filteredTaskCount
  };
}

function countScheduleTasks(schedule: TaskScheduleResponse): number {
  return schedule.fields.reduce(
    (sum, field) => sum + field.schedules.general.length + field.schedules.fertilizer.length,
    0
  );
}
