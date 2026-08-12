import { describe, expect, it, vi } from 'vitest';
import { consumePendingToastKey } from './pending-toast-view.effects';

describe('consumePendingToastKey', () => {
  it('shows success flash and clears key when pending toast key is set', () => {
    const flash = { show: vi.fn() };
    const state = { pendingToast: 'plans.work.toast.record_saved' };

    const result = consumePendingToastKey(
      state,
      state.pendingToast,
      (s) => ({ ...s, pendingToast: null }),
      { flash }
    );

    expect(flash.show).toHaveBeenCalledWith({
      type: 'success',
      text: 'plans.work.toast.record_saved'
    });
    expect(result.pendingToast).toBeNull();
  });

  it('shows structured toast with action and params', () => {
    const flash = { show: vi.fn() };
    const pendingToast = {
      textKey: 'plans.work.toast.record_saved_variance',
      textParams: { name: 'Weeding', deltaDays: '+3', gddDelta: '+10' },
      action: {
        labelKey: 'plans.work.toast.view_task_detail',
        routerLink: ['/plans', 7, 'task_schedule'],
        queryParams: { item_id: 5 }
      }
    };

    consumePendingToastKey(
      { pendingToast },
      pendingToast,
      (state) => ({ ...state, pendingToast: null }),
      { flash }
    );

    expect(flash.show).toHaveBeenCalledWith({
      type: 'success',
      text: pendingToast.textKey,
      textParams: pendingToast.textParams,
      action: pendingToast.action
    });
  });

  it('returns state unchanged when pending toast is null', () => {
    const flash = { show: vi.fn() };
    const state = { pendingToast: null };

    const result = consumePendingToastKey(
      state,
      state.pendingToast,
      (s) => ({ ...s, pendingToast: null }),
      { flash }
    );

    expect(flash.show).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});
