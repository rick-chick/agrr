import { describe, it, expect, beforeEach } from 'vitest';
import { PublicPlanStore } from './public-plan-store.service';

const SESSION_STORAGE_KEY = 'agrr_public_plan_state';

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
});
