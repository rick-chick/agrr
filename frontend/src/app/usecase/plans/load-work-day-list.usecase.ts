import { Inject, Injectable } from '@angular/core';
import { catchError, forkJoin, map, of, switchMap } from 'rxjs';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  groupWorkDayListRows,
  flattenFieldScheduleItems
} from '../../domain/work-schedule/work-day-list-summary';
import { attachLatestWorkRecordAmounts } from '../../domain/work-schedule/work-row-fertilizer';
import { snapshotClimateForDate } from '../../domain/work-schedule/work-record-climate-snapshot';
import { WorkRecord } from '../../models/plans/work-record';
import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { FIELD_CLIMATE_GATEWAY, FieldClimateGateway } from './field-climate/field-climate.gateway';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import {
  LoadWorkDayListInputDto,
  RecentAdHocRecordDto,
  WorkDayListRowDto
} from './load-work-day-list.dtos';
import { LoadWorkDayListInputPort } from './load-work-day-list.input-port';
import {
  LOAD_WORK_DAY_LIST_OUTPUT_PORT,
  LoadWorkDayListOutputPort
} from './load-work-day-list.output-port';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';

function withRecordedToday(row: WorkDayListRowInput, today: string): WorkDayListRowDto {
  return {
    ...row,
    recordedToday: row.item.completed && hasWorkRecordOnDate(row.item, today)
  };
}

function hasWorkRecordOnDate(item: TaskScheduleItem, date: string): boolean {
  return item.work_records.some((record) => record.actual_date === date);
}

type WorkDayListRowInput = Omit<WorkDayListRowDto, 'recordedToday'>;

export function attachCumulativeGddToRows(
  rows: WorkDayListRowInput[],
  cumulativeByField: ReadonlyMap<number, number | null>
): WorkDayListRowInput[] {
  return rows.map((row) => ({
    ...row,
    cumulativeGddAtToday: cumulativeByField.get(row.item.field_cultivation_id) ?? null
  }));
}

export function fetchCumulativeGddByField(
  gateway: FieldClimateGateway,
  fieldIds: number[],
  today: string
) {
  if (fieldIds.length === 0) {
    return of(new Map<number, number | null>());
  }
  return forkJoin(
    fieldIds.map((fieldCultivationId) =>
      gateway
        .fetchFieldClimateData({
          fieldCultivationId,
          planType: 'private',
          displayStartDate: today,
          displayEndDate: today
        })
        .pipe(
          map((data) => {
            const cumulative = snapshotClimateForDate(
              data.gdd_data ?? [],
              data.weather_data ?? [],
              today
            ).gddAtActual;
            return [fieldCultivationId, cumulative] as const;
          }),
          catchError(() => of([fieldCultivationId, null] as const))
        )
    )
  ).pipe(map((entries) => new Map<number, number | null>(entries)));
}

export function findNextScheduled(
  rows: WorkDayListRowInput[],
  today: string,
  includeSkipped: boolean
): WorkDayListRowDto | null {
  let nearest: WorkDayListRowInput | null = null;
  let nearestDate: string | null = null;

  for (const row of rows) {
    const { item } = row;
    if (item.completed) {
      continue;
    }
    if (item.status === 'skipped' && !includeSkipped) {
      continue;
    }
    const scheduled = item.scheduled_date;
    if (!scheduled || scheduled <= today) {
      continue;
    }
    if (nearestDate == null || scheduled < nearestDate) {
      nearest = row;
      nearestDate = scheduled;
    }
  }

  return nearest ? withRecordedToday(nearest, today) : null;
}

export function findTodayAdHocRecord(
  records: WorkRecord[],
  today: string
): RecentAdHocRecordDto | null {
  const adhocToday = records
    .filter((record) => record.task_schedule_item_id == null && record.actual_date === today)
    .sort((a, b) => b.created_at.localeCompare(a.created_at))[0];
  if (!adhocToday) {
    return null;
  }
  return { name: adhocToday.name, actualDate: adhocToday.actual_date };
}

@Injectable()
export class LoadWorkDayListUseCase implements LoadWorkDayListInputPort {
  constructor(
    @Inject(LOAD_WORK_DAY_LIST_OUTPUT_PORT) private readonly outputPort: LoadWorkDayListOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway,
    @Inject(WORK_RECORD_GATEWAY) private readonly workRecordGateway: WorkRecordGateway,
    @Inject(FIELD_CLIMATE_GATEWAY) private readonly fieldClimateGateway: FieldClimateGateway
  ) {}

  execute(dto: LoadWorkDayListInputDto): void {
    forkJoin({
      schedule: this.planGateway.getTaskSchedule(dto.planId),
      records: this.workRecordGateway.listWorkRecords(dto.planId)
    })
      .pipe(
        switchMap(({ schedule, records }) => {
          const fieldIds = [
            ...new Set(schedule.fields.map((field) => field.field_cultivation_id))
          ];
          return fetchCumulativeGddByField(
            this.fieldClimateGateway,
            fieldIds,
            dto.today
          ).pipe(map((cumulativeByField) => ({ schedule, records, cumulativeByField })));
        })
      )
      .subscribe({
        next: ({ schedule, records, cumulativeByField }) => {
          const rows = attachLatestWorkRecordAmounts(
            attachCumulativeGddToRows(
              schedule.fields.flatMap(flattenFieldScheduleItems),
              cumulativeByField
            ),
            records.work_records
          );
        const grouped = groupWorkDayListRows(rows, dto.today, dto.includeSkipped ?? false);
        const recentAdHocRecord =
          grouped.today.length === 0
            ? findTodayAdHocRecord(records.work_records, dto.today)
            : null;
        const listsEmpty =
          grouped.overdue.length === 0 &&
          grouped.today.length === 0 &&
          grouped.upcoming.length === 0;
        const nextScheduled = listsEmpty
          ? findNextScheduled(rows, dto.today, dto.includeSkipped ?? false)
          : null;
        this.outputPort.present({
          plan: schedule.plan,
          fields: schedule.fields,
          ...grouped,
          recentAdHocRecord,
          nextScheduled,
          loadGeneration: dto.loadGeneration
        });
      },
        error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
      });
  }
}
