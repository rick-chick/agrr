import type { CultivationData } from './cultivation-plan-data';
import type {
  WeatherRescheduleGanttOverlayBar,
  WeatherRescheduleProposalPreview
} from './weather-reschedule-proposal-preview';

export function buildWeatherRescheduleGanttOverlayBars(
  preview: WeatherRescheduleProposalPreview,
  cultivations: CultivationData[]
): WeatherRescheduleGanttOverlayBar[] {
  const cultivationById = new Map(cultivations.map((c) => [c.id, c]));
  const bars: WeatherRescheduleGanttOverlayBar[] = [];

  for (const schedule of preview.after.field_schedules) {
    if (!schedule || typeof schedule !== 'object') {
      continue;
    }
    const allocations = (schedule as { allocations?: unknown[] }).allocations ?? [];
    for (const allocation of allocations) {
      if (!allocation || typeof allocation !== 'object') {
        continue;
      }
      const record = allocation as {
        allocation_id?: number;
        start_date?: string;
        completion_date?: string;
      };
      const cultivationId = record.allocation_id;
      if (cultivationId == null) {
        continue;
      }
      const cultivation = cultivationById.get(cultivationId);
      if (!cultivation || !record.start_date) {
        continue;
      }
      const completionDate =
        record.completion_date ??
        addDaysIso(record.start_date, cultivation.cultivation_days);
      bars.push({
        cultivationId,
        cropName: cultivation.crop_name,
        fieldName: cultivation.field_name,
        startDate: record.start_date,
        completionDate
      });
    }
  }

  return bars;
}

function addDaysIso(startDate: string, days: number): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(startDate);
  if (!match) {
    return startDate;
  }
  const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  date.setDate(date.getDate() + days);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}
