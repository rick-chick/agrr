import { describe, expect, it, vi } from 'vitest';
import { consumePendingToastKey } from './pending-toast-view.effects';

describe('consumePendingToastKey', () => {
  it('shows toast and clears key when pendingToastKey is set', () => {
    const toast = { show: vi.fn() };
    const translate = { instant: vi.fn().mockReturnValue('Saved') };

    const state = { pendingToastKey: 'plans.work.toast.record_saved' };
    const result = consumePendingToastKey(
      state,
      state.pendingToastKey,
      (s) => ({ ...s, pendingToastKey: null }),
      { toast, translate }
    );

    expect(translate.instant).toHaveBeenCalledWith('plans.work.toast.record_saved');
    expect(toast.show).toHaveBeenCalledWith('Saved');
    expect(result.pendingToastKey).toBeNull();
  });

  it('returns state unchanged when pendingToastKey is null', () => {
    const toast = { show: vi.fn() };
    const translate = { instant: vi.fn() };

    const state = { pendingToastKey: null };
    const result = consumePendingToastKey(
      state,
      state.pendingToastKey,
      (s) => ({ ...s, pendingToastKey: null }),
      { toast, translate }
    );

    expect(toast.show).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});
