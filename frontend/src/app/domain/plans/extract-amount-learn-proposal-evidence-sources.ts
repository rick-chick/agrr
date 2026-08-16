import type { LearnProposalEvidenceSource } from './learn-proposal-evidence';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import type { PlanFieldSchedule } from '../work-schedule/plan-schedule-snapshot';

function taskTypeByItemId(fields: ReadonlyArray<PlanFieldSchedule>): Map<number, string> {
  const map = new Map<number, string>();
  for (const field of fields) {
    for (const category of ['general', 'fertilizer', 'pest_control', 'unscheduled'] as const) {
      for (const item of field.schedules[category]) {
        if (item.taskType) {
          map.set(item.item_id, item.taskType);
        }
      }
    }
  }
  return map;
}

function amountItems(summary: PlanVsActualSummary): Array<{
  item_id: number;
  category: string;
  name: string;
  actual_date: string | null;
  amount_delta: number;
  status: string;
}> {
  const rows = [...summary.top_variance_items, ...(summary.action_required_items ?? [])];
  return rows.flatMap((item) =>
    item.amount_delta == null
      ? []
      : [
          {
            item_id: item.item_id,
            category: item.category,
            name: item.name,
            actual_date: item.actual_date,
            amount_delta: item.amount_delta,
            status: item.actual_date == null ? 'planned' : 'completed'
          }
        ]
  );
}

export function extractAmountLearnProposalEvidenceSources(
  summary: PlanVsActualSummary | null | undefined,
  fields: ReadonlyArray<PlanFieldSchedule>
): LearnProposalEvidenceSource[] {
  if (!summary) {
    return [];
  }

  const cropIdByItemId = new Map<number, number>();
  for (const field of fields) {
    const cropId = field.crop_id ?? 0;
    for (const category of ['general', 'fertilizer', 'pest_control', 'unscheduled'] as const) {
      for (const item of field.schedules[category]) {
        cropIdByItemId.set(item.item_id, cropId);
      }
    }
  }

  const taskTypes = taskTypeByItemId(fields);

  return amountItems(summary).map((item) => ({
    cropId: cropIdByItemId.get(item.item_id) ?? 0,
    category: item.category,
    taskType: taskTypes.get(item.item_id) ?? null,
    stageOrder: null,
    name: item.name,
    actualDate: item.actual_date,
    deltaDays: null,
    gddDelta: null,
    amountDelta: item.amount_delta,
    status: item.status
  }));
}
