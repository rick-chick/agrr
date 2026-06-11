import { describe, it, expect, beforeEach } from 'vitest';
import { firstValueFrom } from 'rxjs';
import { PublicPlanStore } from './public-plan-store.service';

const SESSION_STORAGE_KEY = 'agrr_public_plan_state';

describe('PublicPlanStore', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('persists pendingCropSlug to sessionStorage and reloads on new instance', async () => {
    const store = new PublicPlanStore();
    store.setPendingCropSlug('tomato');

    const stored = JSON.parse(sessionStorage.getItem(SESSION_STORAGE_KEY)!);
    expect(stored.pendingCropSlug).toBe('tomato');

    const reloaded = new PublicPlanStore();
    expect(reloaded.state.pendingCropSlug).toBe('tomato');
    await expect(firstValueFrom(reloaded.state$)).resolves.toMatchObject({
      pendingCropSlug: 'tomato'
    });
  });

  it('clears pendingCropSlug when set to null', () => {
    const store = new PublicPlanStore();
    store.setPendingCropSlug('tomato');
    store.setPendingCropSlug(null);

    expect(store.state.pendingCropSlug).toBeNull();
    const stored = JSON.parse(sessionStorage.getItem(SESSION_STORAGE_KEY)!);
    expect(stored.pendingCropSlug).toBeNull();
  });

  it('reset clears pendingCropSlug and session storage', () => {
    const store = new PublicPlanStore();
    store.setPendingCropSlug('bell_pepper');
    store.reset();

    expect(store.state.pendingCropSlug).toBeNull();
    expect(sessionStorage.getItem(SESSION_STORAGE_KEY)).toBeNull();
  });
});
