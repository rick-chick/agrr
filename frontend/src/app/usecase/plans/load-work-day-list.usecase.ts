import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { LoadWorkDayListInputDto, LoadWorkDayListDataDto, WorkDayListRowDto } from './load-work-day-list.dtos';
import { LoadWorkDayListInputPort } from './load-work-day-list.input-port';
import {
  LOAD_WORK_DAY_LIST_OUTPUT_PORT,
  LoadWorkDayListOutputPort
} from './load-work-day-list.output-port';

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

export function groupWorkDayListRows(
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

@Injectable()
export class LoadWorkDayListUseCase implements LoadWorkDayListInputPort {
  constructor(
    @Inject(LOAD_WORK_DAY_LIST_OUTPUT_PORT) private readonly outputPort: LoadWorkDayListOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadWorkDayListInputDto): void {
    this.planGateway.getTaskSchedule(dto.planId).subscribe({
      next: (schedule) => {
        const rows = schedule.fields.flatMap(flattenFieldItems);
        const grouped = groupWorkDayListRows(rows, dto.today, dto.includeSkipped ?? false);
        this.outputPort.present({
          plan: schedule.plan,
          fields: schedule.fields,
          ...grouped
        });
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
