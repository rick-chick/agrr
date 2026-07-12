import { Inject, Injectable } from '@angular/core';
import { forkJoin } from 'rxjs';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { WorkRecord } from '../../models/plans/work-record';
import { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import {
  LoadWorkDayListInputDto,
  LoadWorkDayListDataDto,
  RecentAdHocRecordDto,
  WorkDayListRowDto
} from './load-work-day-list.dtos';
import { LoadWorkDayListInputPort } from './load-work-day-list.input-port';
import {
  LOAD_WORK_DAY_LIST_OUTPUT_PORT,
  LoadWorkDayListOutputPort
} from './load-work-day-list.output-port';
import { WORK_RECORD_GATEWAY, WorkRecordGateway } from './work-record-gateway';

const UPCOMING_DAYS = 7;

function parseDate(isoDate: string): Date {
  const [y, m, d] = isoDate.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function addDays(isoDate: string, days: number): string {
  const date = parseDate(isoDate);
  date.setDate(date.getDate() + days);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function flattenFieldItems(field: FieldSchedule): Omit<WorkDayListRowDto, 'recordedToday'>[] {
  const categories = [...field.schedules.general, ...field.schedules.fertilizer];
  return categories.map((item) => ({
    item,
    fieldName: field.name,
    cropName: field.crop_name
  }));
}

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

function groupWorkDayListRows(
  rows: WorkDayListRowInput[],
  today: string,
  includeSkipped: boolean
): Pick<LoadWorkDayListDataDto, 'overdue' | 'today' | 'upcoming'> {
  const upcomingEnd = addDays(today, UPCOMING_DAYS);
  const overdue: WorkDayListRowDto[] = [];
  const todayRows: WorkDayListRowDto[] = [];
  const upcoming: WorkDayListRowDto[] = [];

  for (const row of rows) {
    const { item } = row;
    const isSkipped = item.status === 'skipped';

    if (isSkipped && !includeSkipped) {
      continue;
    }

    if (item.completed) {
      if (hasWorkRecordOnDate(item, today)) {
        todayRows.push(withRecordedToday(row, today));
      }
      continue;
    }

    const scheduled = item.scheduled_date;
    if (!scheduled) {
      continue;
    }

    const enriched = withRecordedToday(row, today);
    if (scheduled < today) {
      overdue.push(enriched);
    } else if (scheduled === today) {
      todayRows.push(enriched);
    } else if (scheduled <= upcomingEnd) {
      upcoming.push(enriched);
    }
  }

  return { overdue, today: todayRows, upcoming };
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
    @Inject(WORK_RECORD_GATEWAY) private readonly workRecordGateway: WorkRecordGateway
  ) {}

  execute(dto: LoadWorkDayListInputDto): void {
    forkJoin({
      schedule: this.planGateway.getTaskSchedule(dto.planId),
      records: this.workRecordGateway.listWorkRecords(dto.planId)
    }).subscribe({
      next: ({ schedule, records }) => {
        const rows = schedule.fields.flatMap(flattenFieldItems);
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
          nextScheduled
        });
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
