import { describe, expect, it } from 'vitest';

import {
  referenceFarmCoordKey,
  resolveReferenceFarmSlug
} from './reference-farm-catalog';

describe('referenceFarmCoordKey', () => {
  it('formats latitude and longitude to four decimal places', () => {
    expect(referenceFarmCoordKey(35.6762, 139.6503)).toBe('35.6762:139.6503');
    expect(referenceFarmCoordKey(30.901, 75.8573)).toBe('30.9010:75.8573');
  });
});

describe('resolveReferenceFarmSlug', () => {
  it('resolves Tokyo coordinates to catalog slug', () => {
    expect(
      resolveReferenceFarmSlug({
        name: 'Tokyo',
        latitude: 35.6762,
        longitude: 139.6503,
        region: 'jp'
      })
    ).toBe('jp_35p6762_139p6503');
  });

  it('resolves legacy Punjab alias when coordinates match catalog entry', () => {
    expect(
      resolveReferenceFarmSlug({
        name: 'Punjab',
        latitude: 30.901,
        longitude: 75.8573,
        region: 'in'
      })
    ).toBe('in_30p9010_75p8573');
  });

  it('falls back to region:name alias when coordinates are unknown', () => {
    expect(
      resolveReferenceFarmSlug({
        name: 'Punjab',
        latitude: 0,
        longitude: 0,
        region: 'in'
      })
    ).toBe('in_30p9010_75p8573');
  });

  it('returns undefined when neither coordinates nor alias match', () => {
    expect(
      resolveReferenceFarmSlug({
        name: 'Unknown Farm',
        latitude: 0,
        longitude: 0,
        region: 'jp'
      })
    ).toBeUndefined();
  });

  it('returns undefined when alias lookup lacks region', () => {
    expect(
      resolveReferenceFarmSlug({
        name: 'Punjab',
        latitude: 0,
        longitude: 0
      })
    ).toBeUndefined();
  });
});
