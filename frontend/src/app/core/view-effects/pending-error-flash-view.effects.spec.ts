import { vi } from 'vitest';
import { consumePendingErrorFlash } from './pending-error-flash-view.effects';

describe('consumePendingErrorFlash', () => {
  it('shows error flash and clears pending request when set', () => {
    const flash = { show: vi.fn() };
    const state = {
      pendingErrorFlash: {
        type: 'error' as const,
        text: 'Network error'
      }
    };

    const result = consumePendingErrorFlash(state, { flash });

    expect(flash.show).toHaveBeenCalledWith({ type: 'error', text: 'Network error' });
    expect(result.pendingErrorFlash).toBeNull();
  });

  it('returns state unchanged when pendingErrorFlash is null', () => {
    const flash = { show: vi.fn() };
    const state = { pendingErrorFlash: null };

    const result = consumePendingErrorFlash(state, { flash });

    expect(flash.show).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});
