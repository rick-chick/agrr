import {
  buildEntryScheduleDetailCanonicalUrl,
  buildEntryScheduleDetailSeoLabels,
} from './entry-schedule-detail-seo-meta';

describe('entry-schedule-detail-seo-meta', () => {
  it('builds labels from crop name', () => {
    expect(buildEntryScheduleDetailSeoLabels(' トマト ')).toEqual({ cropName: 'トマト' });
  });

  it('builds self-referencing canonical without farmId query', () => {
    expect(buildEntryScheduleDetailCanonicalUrl('https://agrr.net', 1)).toBe(
      'https://agrr.net/entry-schedule/crop/1'
    );
    expect(buildEntryScheduleDetailCanonicalUrl('', 1)).toBe('');
  });
});
