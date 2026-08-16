import { TaskScheduleItem } from '../../models/plans/task-schedule';
import { WorkRecord } from '../../models/plans/work-record';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import {
  computeWorkRecordAmountDiff,
  isAmountTrackedScheduleCategory,
  WorkRecordAmountDiff
} from './work-record-amount-diff';

export type WorkListSegment = 'all' | 'fertilizer' | 'pest_control';

export type FertilizerTaskKind = 'basal' | 'topdress';

export type PestControlTaskKind = 'preventive' | 'curative';

type WorkDayListRowAmountTarget = Pick<WorkDayListRowDto, 'item'> & {
  latestRecordAmount?: string | null;
  latestRecordAmountUnit?: string | null;
};

export function isFertilizerWorkRow(row: WorkDayListRowDto): boolean {
  return row.item.category === 'fertilizer';
}

export function isPestControlWorkRow(row: WorkDayListRowDto): boolean {
  return row.item.category === 'pest_control';
}

export function resolveFertilizerTaskKind(item: TaskScheduleItem): FertilizerTaskKind | null {
  if (item.task_type === 'basal_fertilization') {
    return 'basal';
  }
  if (item.task_type === 'topdress_fertilization') {
    return 'topdress';
  }
  return null;
}

export function resolvePestControlTaskKind(item: TaskScheduleItem): PestControlTaskKind | null {
  if (item.task_type === 'preventive_spray') {
    return 'preventive';
  }
  if (item.task_type === 'curative_spray') {
    return 'curative';
  }
  return null;
}

export function filterWorkDayListBySegment(
  rows: WorkDayListRowDto[],
  segment: WorkListSegment
): WorkDayListRowDto[] {
  if (segment === 'all') {
    return rows;
  }
  if (segment === 'fertilizer') {
    return rows.filter(isFertilizerWorkRow);
  }
  return rows.filter(isPestControlWorkRow);
}

function findLatestWorkRecordForItem(
  records: WorkRecord[],
  itemId: number
): WorkRecord | null {
  const matches = records
    .filter((record) => record.task_schedule_item_id === itemId)
    .sort((a, b) => b.created_at.localeCompare(a.created_at));
  return matches[0] ?? null;
}

export function attachLatestWorkRecordAmounts<T extends WorkDayListRowAmountTarget>(
  rows: T[],
  records: WorkRecord[]
): T[] {
  return rows.map((row) => {
    const latest = findLatestWorkRecordForItem(records, row.item.item_id);
    if (!latest) {
      return row;
    }
    return {
      ...row,
      latestRecordAmount: latest.amount,
      latestRecordAmountUnit: latest.amount_unit
    };
  });
}

export function resolveWorkRowAmountDiff(
  row: WorkDayListRowDto,
  actualAmount?: string | null,
  actualUnit?: string | null
): WorkRecordAmountDiff | null {
  if (!isAmountTrackedScheduleCategory(row.item.category)) {
    return null;
  }
  const plannedAmount = row.item.amount ?? '';
  const plannedUnit = row.item.amount_unit ?? '';
  const resolvedActual = actualAmount ?? row.latestRecordAmount ?? '';
  const resolvedUnit = actualUnit ?? row.latestRecordAmountUnit ?? plannedUnit;
  return computeWorkRecordAmountDiff(plannedAmount, resolvedActual, resolvedUnit);
}

export function formatWorkRowAmountDiffLabel(diff: WorkRecordAmountDiff): string {
  if (diff.diff == null) {
    return '';
  }
  const sign = diff.diff > 0 ? '+' : '';
  return `${sign}${diff.diff}${diff.unit ? ` ${diff.unit}` : ''}`;
}
