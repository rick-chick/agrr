import type { PlanVarianceActionItem } from './plan-vs-actual-summary';
import type { WorkRecord } from '../../models/plans/work-record';

export function findVarianceActionItemForRecord(
  record: WorkRecord,
  actionItems: ReadonlyArray<PlanVarianceActionItem>
): PlanVarianceActionItem | null {
  const itemId = record.task_schedule_item_id;
  if (itemId == null) {
    return null;
  }
  return actionItems.find((item) => item.item_id === itemId) ?? null;
}
