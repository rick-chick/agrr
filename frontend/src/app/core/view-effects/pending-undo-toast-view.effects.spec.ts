import { vi } from 'vitest';
import { consumePendingUndoToast } from './pending-undo-toast-view.effects';

describe('consumePendingUndoToast', () => {
  it('shows undo toast and clears pending request when set', () => {
    const toast = { showWithUndo: vi.fn() };
    const onRestored = vi.fn();
    const state = {
      pendingUndoToast: {
        message: 'Deleted',
        undoPath: '/undo?token=abc',
        undoToken: 'abc',
        onRestored,
        resourceLabel: 'Plan A'
      }
    };

    const result = consumePendingUndoToast(state, { toast });

    expect(toast.showWithUndo).toHaveBeenCalledWith(
      'Deleted',
      '/undo?token=abc',
      'abc',
      onRestored,
      'Plan A'
    );
    expect(result.pendingUndoToast).toBeNull();
  });

  it('returns state unchanged when pendingUndoToast is null', () => {
    const toast = { showWithUndo: vi.fn() };
    const state = { pendingUndoToast: null };

    const result = consumePendingUndoToast(state, { toast });

    expect(toast.showWithUndo).not.toHaveBeenCalled();
    expect(result).toBe(state);
  });
});
