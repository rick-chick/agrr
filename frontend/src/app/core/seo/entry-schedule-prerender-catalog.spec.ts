import {
  ENTRY_SCHEDULE_PRERENDER_CATALOG,
  ENTRY_SCHEDULE_SEO_SAMPLE_CROP,
  entryScheduleCropDetailPath,
  entryScheduleCropPrerenderPaths,
  findEntrySchedulePrerenderCrop,
} from './entry-schedule-prerender-catalog';

describe('entry-schedule-prerender-catalog', () => {
  it('lists all JP reference crops with stable production ids', () => {
    expect(ENTRY_SCHEDULE_PRERENDER_CATALOG.crops).toHaveLength(15);
    expect(findEntrySchedulePrerenderCrop(1)?.name).toBe('トマト');
    expect(findEntrySchedulePrerenderCrop(99)).toBeUndefined();
  });

  it('uses tomato as representative SEO sample crop', () => {
    expect(ENTRY_SCHEDULE_SEO_SAMPLE_CROP.cropId).toBe(1);
    expect(ENTRY_SCHEDULE_SEO_SAMPLE_CROP.name).toBe('トマト');
  });

  it('builds crop detail paths for prerender and sitemap', () => {
    expect(entryScheduleCropDetailPath(1)).toBe('/entry-schedule/crop/1');
    expect(entryScheduleCropPrerenderPaths()).toContain('entry-schedule/crop/1');
    expect(entryScheduleCropPrerenderPaths()).toHaveLength(15);
  });
});
