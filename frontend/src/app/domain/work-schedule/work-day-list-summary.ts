import { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';

const UPCOMING_DAYS = 7;

export interface WorkDayListCounts {
  overdueCount: number;
  todayCount: number;
}

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

function daysOverdue(scheduled: string, today: string): number {
  const scheduledDate = parseDate(scheduled);
  const todayDate = parseDate(today);
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((todayDate.getTime() - scheduledDate.getTime()) / msPerDay);
}

export function flattenFieldScheduleItems(
  field: FieldSchedule
): Omit<WorkDayListRowDto, 'recordedToday'>[] {
  const categories = [
    ...field.schedules.general,
    ...field.schedules.fertilizer,
    ...field.schedules.pest_control
  ];
  return categories.map((item) => ({
    item,
    fieldName: field.name,
    cropName: field.crop_name
  }));
}

function withRecordedToday(
  row: Omit<WorkDayListRowDto, 'recordedToday'>,
  today: string
): WorkDayListRowDto {
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
): {
  overdue: WorkDayListRowDto[];
  today: WorkDayListRowDto[];
  upcoming: WorkDayListRowDto[];
} {
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
      overdue.push({ ...enriched, overdueDays: daysOverdue(scheduled, today) });
    } else if (scheduled === today) {
      todayRows.push(enriched);
    } else if (scheduled <= upcomingEnd) {
      upcoming.push(enriched);
    }
  }

  return { overdue, today: todayRows, upcoming };
}

export function countWorkDayListFromFields(
  fields: FieldSchedule[],
  today: string,
  includeSkipped = false
): WorkDayListCounts {
  const rows = fields.flatMap(flattenFieldScheduleItems);
  const grouped = groupWorkDayListRows(rows, today, includeSkipped);
  return {
    overdueCount: grouped.overdue.length,
    todayCount: grouped.today.length
  };
}

export function sumOverdueCounts(counts: Pick<WorkDayListCounts, 'overdueCount'>[]): number {
  return counts.reduce((total, count) => total + count.overdueCount, 0);
}
