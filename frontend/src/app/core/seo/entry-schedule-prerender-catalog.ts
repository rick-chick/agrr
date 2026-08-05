import catalogJson from './entry-schedule-prerender-catalog.json';

export interface EntrySchedulePrerenderCrop {
  cropId: number;
  name: string;
}

export interface EntrySchedulePrerenderCatalog {
  defaultFarmId: number;
  region: string;
  crops: EntrySchedulePrerenderCrop[];
}

export const ENTRY_SCHEDULE_PRERENDER_CATALOG = catalogJson as EntrySchedulePrerenderCatalog;

/** Representative crop for verify-seo-routing and smoke checks. */
export const ENTRY_SCHEDULE_SEO_SAMPLE_CROP =
  ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.find((c) => c.name === 'トマト') ??
  ENTRY_SCHEDULE_PRERENDER_CATALOG.crops[0];

export function findEntrySchedulePrerenderCrop(
  cropId: number
): EntrySchedulePrerenderCrop | undefined {
  return ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.find((c) => c.cropId === cropId);
}

export function entryScheduleCropDetailPath(cropId: number): string {
  return `/entry-schedule/crop/${cropId}`;
}

export function entryScheduleCropPrerenderPaths(): string[] {
  return ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.map(
    (c) => `entry-schedule/crop/${c.cropId}`
  );
}
