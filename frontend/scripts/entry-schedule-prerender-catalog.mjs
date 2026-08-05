import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const catalogPath = join(
  __dirname,
  '../src/app/core/seo/entry-schedule-prerender-catalog.json',
);

/** @type {{ defaultFarmId: number, region: string, crops: Array<{ cropId: number, name: string }> }} */
export const ENTRY_SCHEDULE_PRERENDER_CATALOG = JSON.parse(
  readFileSync(catalogPath, 'utf8'),
);

export const ENTRY_SCHEDULE_SEO_SAMPLE_CROP =
  ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.find((c) => c.name === 'トマト') ??
  ENTRY_SCHEDULE_PRERENDER_CATALOG.crops[0];

/** @param {number} cropId */
export function entryScheduleCropDetailPath(cropId) {
  return `/entry-schedule/crop/${cropId}`;
}

export function entryScheduleCropPrerenderPaths() {
  return ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.map(
    (c) => `entry-schedule/crop/${c.cropId}`,
  );
}

export function entryScheduleCropSitemapPaths() {
  return ENTRY_SCHEDULE_PRERENDER_CATALOG.crops.map((c) =>
    entryScheduleCropDetailPath(c.cropId),
  );
}
