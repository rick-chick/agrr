import { vi } from 'vitest';
import { applyPendingFlashViewEffects, consumePendingSuccessFlash } from './pending-success-flash-view.effects';

describe('consumePendingSuccessFlash', () => {
  it('shows success flash and clears pending request when set', () => {
    const flash = { show: vi.fn() };
    const state = {
      pendingSuccessFlash: {
        type: 'success' as const,
        text: 'crops.flash.updated'
      }
    };

    const result = consumePendingSuccessFlash(state, { flash });

    expect(flash.show).toHaveBeenCalledWith({ type: 'success', text: 'crops.flash.updated' });
    expect(result.pendingSuccessFlash).toBeNull();
  });

  it('returns state unchanged when pendingSuccessFlash is null', () => {
    const flash = { show: vi.fn() };
    const state = { pendingSuccessFlash: null };

    const result = consumePendingSuccessFlash(state, { flash });

    expect(flash.show).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});

describe('applyPendingFlashViewEffects', () => {
  it('consumes pending error then pending success flash', () => {
    const flash = { show: vi.fn() };
    const state = {
      pendingErrorFlash: { type: 'error' as const, text: 'Failed' },
      pendingSuccessFlash: { type: 'success' as const, text: 'Saved' }
    };

    const result = applyPendingFlashViewEffects(state, { flash });

    expect(flash.show).toHaveBeenCalledTimes(2);
    expect(flash.show).toHaveBeenNthCalledWith(1, { type: 'error', text: 'Failed' });
    expect(flash.show).toHaveBeenNthCalledWith(2, { type: 'success', text: 'Saved' });
    expect(result.pendingErrorFlash).toBeNull();
    expect(result.pendingSuccessFlash).toBeNull();
  });
});
