import type { EntryScheduleCropShowResponse } from '../../domain/entry-schedule/entry-schedule';
import {
  ENTRY_SCHEDULE_PRERENDER_CATALOG,
  type EntrySchedulePrerenderCrop,
} from './entry-schedule-prerender-catalog';

/** Static body copy for build-time prerender when the public API is unavailable. */
export function entrySchedulePrerenderReasonSummary(cropName: string): string {
  return `${cropName}の播種・定植・収穫の適期帯を、地域の予測気象データに基づいて確認できます。`;
}

export function buildEntrySchedulePrerenderSnapshot(
  crop: EntrySchedulePrerenderCrop
): EntryScheduleCropShowResponse {
  return {
    farm: {
      id: ENTRY_SCHEDULE_PRERENDER_CATALOG.defaultFarmId,
      name: '埼玉',
      latitude: 35.8569,
      longitude: 139.6489,
      region: ENTRY_SCHEDULE_PRERENDER_CATALOG.region,
    },
    prediction: {
      chart_calendar_year: new Date().getFullYear(),
    },
    crop: {
      id: crop.cropId,
      name: crop.name,
      eligible: true,
      sowing_summary: null,
      transplant_summary: null,
      reason_summary: entrySchedulePrerenderReasonSummary(crop.name),
      labels: { sowing: '播種', transplanting: '定植' },
      sowing_windows: [],
      transplant_windows: [],
      reason_parts: {},
      sowing_stage_id: null,
      transplant_stage_id: null,
      crop_stages: [],
      entry_disclaimer:
        '表示内容は予測気象に基づく目安です。実際の作付けは地域の気候・栽培条件に合わせて判断してください。',
    },
  };
}
