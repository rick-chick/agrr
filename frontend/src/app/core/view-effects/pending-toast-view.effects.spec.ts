import { vi } from 'vitest';
import { consumePendingToastKey } from './pending-toast-view.effects';

describe('consumePendingToastKey', () => {
  it('shows success flash and clears key when pendingToastKey is set', () => {
    const flash = { show: vi.fn() };

    const state = { pendingToastKey: 'plans.work.toast.record_saved' };
    const result = consumePendingToastKey(
      state,
      state.pendingToastKey,
      (s) => ({ ...s, pendingToastKey: null }),
      { flash }
    );

    expect(flash.show).toHaveBeenCalledWith({
      type: 'success',
      text: 'plans.work.toast.record_saved'
    });
    expect(result.pendingToastKey).toBeNull();
  });

  it('returns state unchanged when pendingToastKey is null', () => {
    const flash = { show: vi.fn() };

    const state = { pendingToastKey: null };
    const result = consumePendingToastKey(
      state,
      state.pendingToastKey,
      (s) => ({ ...s, pendingToastKey: null }),
      { flash }
    );

    expect(flash.show).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});
