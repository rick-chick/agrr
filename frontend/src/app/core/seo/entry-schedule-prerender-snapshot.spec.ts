import { describe, expect, it } from 'vitest';

import { buildEntrySchedulePrerenderSnapshot } from './entry-schedule-prerender-snapshot';

describe('buildEntrySchedulePrerenderSnapshot', () => {
  const crop = { cropId: 1, name: 'Tomato' };

  it('uses English API disclaimer and labels for en locale', () => {
    const snapshot = buildEntrySchedulePrerenderSnapshot(crop, 'en');

    expect(snapshot.crop.entry_disclaimer).toContain('guide only');
    expect(snapshot.crop.labels.sowing).toBe('Sowing window (guide)');
    expect(snapshot.crop.labels.transplanting).toBe('Transplanting window (guide)');
    expect(snapshot.crop.reason_summary).toContain('Tomato');
    expect(snapshot.crop.reason_summary).not.toMatch(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/);
  });

  it('uses Hindi API disclaimer for in locale', () => {
    const snapshot = buildEntrySchedulePrerenderSnapshot(crop, 'in');

    expect(snapshot.crop.entry_disclaimer).toContain('मार्गदर्शक');
    expect(snapshot.crop.labels.sowing).toBe('बुवाई अवधि (मार्गदर्शक)');
    expect(snapshot.crop.reason_summary).toContain('Tomato');
    expect(snapshot.crop.reason_summary).not.toMatch(/[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/);
  });
});
