import { describe, it, expect, beforeEach } from 'vitest';
import { PublicPlanStore } from './public-plan-store.service';

const SESSION_STORAGE_KEY = 'agrr_public_plan_state';

describe('PublicPlanStore pendingCropId', () => {
  it('persists pendingCropId when setPendingCropId is called', () => {
    const store = new PublicPlanStore();

    store.setPendingCropId(42);

    expect(store.state.pendingCropId).toBe(42);
    const stored = JSON.parse(sessionStorage.getItem('agrr_public_plan_state') ?? '{}');
    expect(stored.pendingCropId).toBe(42);
  });

  it('clears pendingCropId on reset', () => {
    const store = new PublicPlanStore();
    store.setPendingCropId(42);
    store.reset();
    expect(store.state.pendingCropId).toBeNull();
  });
});

describe('PublicPlanStore pendingCropSlug', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('restores pendingCropSlug from session storage on construction', () => {
    sessionStorage.setItem(
      SESSION_STORAGE_KEY,
      JSON.stringify({ pendingCropSlug: 'tomato' })
    );

    const store = new PublicPlanStore();

    expect(store.state.pendingCropSlug).toBe('tomato');
  });

  it('persists pendingCropSlug when setPendingCropSlug is called', () => {
    const store = new PublicPlanStore();

    store.setPendingCropSlug('bell_pepper');

    expect(store.state.pendingCropSlug).toBe('bell_pepper');
    const stored = JSON.parse(sessionStorage.getItem(SESSION_STORAGE_KEY)!);
    expect(stored.pendingCropSlug).toBe('bell_pepper');
  });

  it('clears pendingCropSlug on reset', () => {
    const store = new PublicPlanStore();
    store.setPendingCropSlug('tomato');

    store.reset();

    expect(store.state.pendingCropSlug).toBeNull();
    expect(sessionStorage.getItem(SESSION_STORAGE_KEY)).toBeNull();
  });

  it('syncFromSessionStorageIfFarmMissing restores farm seeded after construction', () => {
    const store = new PublicPlanStore();
    expect(store.state.farm).toBeNull();

    sessionStorage.setItem(
      SESSION_STORAGE_KEY,
      JSON.stringify({
        farm: { id: 2, name: '東京', region: 'jp', latitude: 35.6, longitude: 139.7 },
        farmSize: { id: '300', area_sqm: 300, name: '300㎡', description: '' },
        selectedCrops: [],
        planId: null,
        pendingCropSlug: null,
      }),
    );

    store.syncFromSessionStorageIfFarmMissing();

    expect(store.state.farm?.id).toBe(2);
    expect(store.state.farm?.name).toBe('東京');
  });
});
