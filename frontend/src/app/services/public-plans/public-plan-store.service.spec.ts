import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { PublicPlanStore } from './public-plan-store.service';
import { PUBLIC_PLAN_STATE_STORAGE_KEY } from './public-plan-browser-storage';

describe('PublicPlanStore pendingCropSlug', () => {
  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('restores pendingCropSlug from localStorage on construction', () => {
    localStorage.setItem(
      PUBLIC_PLAN_STATE_STORAGE_KEY,
      JSON.stringify({ pendingCropSlug: 'tomato' })
    );

    const store = new PublicPlanStore();

    expect(store.state.pendingCropSlug).toBe('tomato');
  });

  it('persists pendingCropSlug when setPendingCropSlug is called', () => {
    const store = new PublicPlanStore();

    store.setPendingCropSlug('bell_pepper');

    expect(store.state.pendingCropSlug).toBe('bell_pepper');
    const stored = JSON.parse(localStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)!);
    expect(stored.pendingCropSlug).toBe('bell_pepper');
  });

  it('persists pendingCropId when setPendingCropId is called', () => {
    const store = new PublicPlanStore();

    store.setPendingCropId(42);

    expect(store.state.pendingCropId).toBe(42);
    const stored = JSON.parse(localStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)!);
    expect(stored.pendingCropId).toBe(42);
  });

  it('clears pendingCropSlug on reset', () => {
    const store = new PublicPlanStore();
    store.setPendingCropSlug('tomato');

    store.reset();

    expect(store.state.pendingCropSlug).toBeNull();
    expect(localStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toBeNull();
  });

  it('syncFromSessionStorageIfFarmMissing restores farm seeded after construction', () => {
    const store = new PublicPlanStore();
    expect(store.state.farm).toBeNull();

    localStorage.setItem(
      PUBLIC_PLAN_STATE_STORAGE_KEY,
      JSON.stringify({
        farm: { id: 2, name: '東京', region: 'jp', latitude: 35.6, longitude: 139.7 },
        farmSize: { id: '300', area_sqm: 300, name: '300㎡', description: '' },
        selectedCrops: [],
        planId: null,
        pendingCropSlug: null,
        pendingCropId: null
      }),
    );

    store.syncFromSessionStorageIfFarmMissing();

    expect(store.state.farm?.id).toBe(2);
    expect(store.state.farm?.name).toBe('東京');
  });

  it('migrates legacy sessionStorage state into localStorage on construction', () => {
    sessionStorage.setItem(
      PUBLIC_PLAN_STATE_STORAGE_KEY,
      JSON.stringify({ pendingCropSlug: 'eggplant' })
    );

    const store = new PublicPlanStore();

    expect(store.state.pendingCropSlug).toBe('eggplant');
    expect(localStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toContain('eggplant');
    expect(sessionStorage.getItem(PUBLIC_PLAN_STATE_STORAGE_KEY)).toBeNull();
  });

  it('records persist failure when localStorage write fails', () => {
    const store = new PublicPlanStore();
    const originalLocalStorage = globalThis.localStorage;
    vi.stubGlobal('localStorage', {
      getItem: originalLocalStorage.getItem.bind(originalLocalStorage),
      removeItem: originalLocalStorage.removeItem.bind(originalLocalStorage),
      clear: originalLocalStorage.clear.bind(originalLocalStorage),
      key: originalLocalStorage.key.bind(originalLocalStorage),
      get length() {
        return originalLocalStorage.length;
      },
      setItem: () => {
        throw new DOMException('quota', 'QuotaExceededError');
      },
    });

    store.setPendingCropSlug('tomato');

    expect(store.hadPersistFailure).toBe(true);
  });
});
