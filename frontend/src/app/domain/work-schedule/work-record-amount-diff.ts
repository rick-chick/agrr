export interface WorkRecordAmountDiff {
  planned: number | null;
  actual: number | null;
  diff: number | null;
  unit: string;
}

export function parseWorkRecordAmount(value: string): number | null {
  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }
  const parsed = Number(trimmed);
  return Number.isFinite(parsed) ? parsed : null;
}

export function computeWorkRecordAmountDiff(
  plannedAmount: string,
  actualAmount: string,
  unit: string
): WorkRecordAmountDiff | null {
  const planned = parseWorkRecordAmount(plannedAmount);
  const actual = parseWorkRecordAmount(actualAmount);
  if (planned == null && actual == null) {
    return null;
  }
  const diff = planned != null && actual != null ? actual - planned : null;
  return { planned, actual, diff, unit };
}
