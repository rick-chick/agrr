import { AMOUNT_VARIANCE_THRESHOLD } from '../plans/plan-variance-thresholds';

export type PlanTaskScheduleAmountVarianceBadgeKind = 'over' | 'under';

export type PlanTaskScheduleAmountVarianceBadge = {
  kind: PlanTaskScheduleAmountVarianceBadgeKind;
  amountDelta: number;
};

export function resolvePlanTaskScheduleAmountVarianceBadge(
  item: Pick<PlanTaskScheduleItemAmountVarianceFields, 'status' | 'amountDelta'>
): PlanTaskScheduleAmountVarianceBadge | null {
  if (item.status.toLowerCase() === 'skipped' || item.amountDelta == null) {
    return null;
  }

  if (Math.abs(item.amountDelta) < AMOUNT_VARIANCE_THRESHOLD) {
    return null;
  }

  return item.amountDelta > 0
    ? { kind: 'over', amountDelta: item.amountDelta }
    : { kind: 'under', amountDelta: item.amountDelta };
}

export type PlanTaskScheduleItemAmountVarianceFields = {
  status: string;
  amountDelta: number | null | undefined;
};
