import { describe, it, expect } from 'vitest';
import { findCropByResearchSlug } from './research-crop-slug';
import { Crop } from '../crops/crop';

const crop = (id: number, name: string): Crop => ({
  id,
  name,
  variety: null,
  is_reference: true,
  area_per_unit: null,
  revenue_per_area: null,
  region: 'jp',
  groups: [],
  created_at: null,
  updated_at: null
});

describe('findCropByResearchSlug', () => {
  it('matches tomato slug to トマト reference crop', () => {
    const crops = [crop(1, 'トマト'), crop(2, 'キュウリ')];
    expect(findCropByResearchSlug(crops, 'tomato')?.id).toBe(1);
  });

  it('matches bell_pepper without confusing with other peppers', () => {
    const crops = [crop(1, 'ピーマン'), crop(2, 'トマト')];
    expect(findCropByResearchSlug(crops, 'bell_pepper')?.name).toBe('ピーマン');
  });

  it('returns undefined for unknown slug', () => {
    expect(findCropByResearchSlug([crop(1, 'トマト')], 'unknown')).toBeUndefined();
  });
});
