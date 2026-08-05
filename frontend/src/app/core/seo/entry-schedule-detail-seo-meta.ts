import { entryScheduleCropDetailPath } from './entry-schedule-prerender-catalog';

export interface EntryScheduleDetailSeoLabels {
  cropName: string;
}

/** @internal exported for unit tests */
export function buildEntryScheduleDetailSeoLabels(
  cropName: string
): EntryScheduleDetailSeoLabels {
  return { cropName: cropName.trim() };
}

/** Self-referencing canonical without farmId query (SEO landing URL). */
export function buildEntryScheduleDetailCanonicalUrl(
  origin: string,
  cropId: number
): string {
  if (!origin || !cropId) {
    return '';
  }
  return `${origin.replace(/\/$/, '')}${entryScheduleCropDetailPath(cropId)}`;
}
