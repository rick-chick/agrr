import type { LearnProposalEvidenceSource } from './learn-proposal-evidence';
import type {
  PlanFieldSchedule,
  PlanTaskScheduleItem
} from '../work-schedule/plan-schedule-snapshot';

function pushScheduleItems(
  sources: LearnProposalEvidenceSource[],
  cropId: number,
  category: string,
  items: ReadonlyArray<PlanTaskScheduleItem>
): void {
  for (const item of items) {
    sources.push({
      cropId,
      category,
      stageOrder: item.stageOrder ?? null,
      name: item.name,
      actualDate: item.actualDate,
      deltaDays: item.deltaDays,
      gddDelta: item.gddDelta,
      status: item.status
    });
  }
}

export function extractLearnProposalEvidenceSources(
  fields: ReadonlyArray<PlanFieldSchedule>
): LearnProposalEvidenceSource[] {
  const sources: LearnProposalEvidenceSource[] = [];

  for (const field of fields) {
    const cropId = field.crop_id ?? 0;
    pushScheduleItems(sources, cropId, 'general', field.schedules.general);
    pushScheduleItems(sources, cropId, 'fertilizer', field.schedules.fertilizer);
    pushScheduleItems(sources, cropId, 'unscheduled', field.schedules.unscheduled);
  }

  return sources;
}
